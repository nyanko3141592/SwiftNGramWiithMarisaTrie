import Foundation
import SwiftyMarisa

/// Base64 でエンコードされた Key-Value をデコードする関数
private func decodeKeyValue(_ foundString: String, key: String) -> UInt32? {
    let base64value = String(foundString.dropFirst(key.count))
    guard let valueData = Data(base64Encoded: base64value) else {
        return nil
    }
    guard valueData.count == 4 else {
        return nil
    }
    return valueData.withUnsafeBytes { rawBuffer in
        rawBuffer.load(as: UInt32.self).littleEndian
    }
}

/// Trie から Key に対応する Value を取得する関数
private func getValue(from trie: Marisa, key: String) -> UInt32? {
    let prefixB64 = key + "@"
    let results = trie.search(prefixB64, .predictive)
    for result in results {
        if let decoded = decodeKeyValue(result, key: prefixB64) {
            return decoded
        }
    }
    return nil
}

/// Kneser-Ney 言語モデル
public class LM {
    public let n: Int
    public let eos: String = "</s>"
    public let d: Double

    // Tries
    let c_abc: Marisa
    let c_abx: Marisa
    let u_abx: Marisa
    let u_xbc: Marisa
    let u_xbx: Marisa
    let r_xbx: Marisa
    let vocabTrie: Marisa

    // 語彙セット
    public var vocabSet: Set<String>

    // キャッシュ
    private var predictCache: [String: Double]
    private var c_abcCache: [String: UInt32?]
    private var c_abxCache: [String: UInt32?]
    private var u_abxCache: [String: UInt32?]
    private var u_xbcCache: [String: UInt32?]
    private var u_xbxCache: [String: UInt32?]
    private var r_xbxCache: [String: UInt32?]

    // 総トークン数 (ユニグラム計算用)
    private var totalTokens: UInt32

    public init?(baseFilename: String, n: Int, d: Double) {
        // ストアドプロパティを一度に全て初期化（“仮”の値で OK）
        self.n = n
        self.d = d

        self.c_abc = Marisa()
        self.c_abx = Marisa()
        self.u_abx = Marisa()
        self.u_xbc = Marisa()
        self.u_xbx = Marisa()
        self.r_xbx = Marisa()
        self.vocabTrie = Marisa()

        self.vocabSet = Set<String>()

        self.predictCache = [:]
        self.c_abcCache = [:]
        self.c_abxCache = [:]
        self.u_abxCache = [:]
        self.u_xbcCache = [:]
        self.u_xbxCache = [:]
        self.r_xbxCache = [:]

        self.totalTokens = 0

        // ロード
        do {
            try c_abc.load("\(baseFilename)_c_abc.marisa")
            try c_abx.load("\(baseFilename)_c_abx.marisa")
            try u_abx.load("\(baseFilename)_u_abx.marisa")
            try u_xbc.load("\(baseFilename)_u_xbc.marisa")
            try u_xbx.load("\(baseFilename)_u_xbx.marisa")
            try r_xbx.load("\(baseFilename)_r_xbx.marisa")
            try vocabTrie.load("\(baseFilename)_vocab.marisa")
        } catch {
            // ロード失敗時は nil
            return nil
        }

        // 語彙セット
        self.vocabSet = Set(vocabTrie.search("", .predictive))

        // 全てのストアドプロパティに仮の値が入ったので、ここから初めて self のメソッドを呼べる
        // totalTokens の最終値をセット
        self.totalTokens = getValueC_abx("") ?? 1
    }

    private func getValueC_abc(_ key: String) -> UInt32? {
        if let cached = c_abcCache[key] {
            return cached
        }
        let val = getValue(from: c_abc, key: key)
        c_abcCache[key] = val
        return val
    }

    private func getValueC_abx(_ key: String) -> UInt32? {
        if let cached = c_abxCache[key] {
            return cached
        }
        let val = getValue(from: c_abx, key: key)
        c_abxCache[key] = val
        return val
    }

    private func getValueU_abx(_ key: String) -> UInt32? {
        if let cached = u_abxCache[key] {
            return cached
        }
        let val = getValue(from: u_abx, key: key)
        u_abxCache[key] = val
        return val
    }

    private func getValueU_xbc(_ key: String) -> UInt32? {
        if let cached = u_xbcCache[key] {
            return cached
        }
        let val = getValue(from: u_xbc, key: key)
        u_xbcCache[key] = val
        return val
    }

    private func getValueU_xbx(_ key: String) -> UInt32? {
        if let cached = u_xbxCache[key] {
            return cached
        }
        let val = getValue(from: u_xbx, key: key)
        u_xbxCache[key] = val
        return val
    }

    private func getValueR_xbx(_ key: String) -> UInt32? {
        if let cached = r_xbxCache[key] {
            return cached
        }
        let val = getValue(from: r_xbx, key: key)
        r_xbxCache[key] = val
        return val
    }

    /// Kneser-Ney の確率を求める
    public func predict(_ ngram: [String]) -> Double {
        // キャッシュにある場合は即返す
        let joinedKey = ngram.joined(separator: "|")
        if let cached = predictCache[joinedKey] {
            return cached
        }

        // ユニグラムの場合（再帰の終了条件）
        if ngram.count == 1 {
            let c = ngram[0]
            let c_abc_c = getValueC_abc(c) ?? 0
            let prob = Double(c_abc_c) / Double(totalTokens)
            predictCache[joinedKey] = prob
            return prob
        }

        // ngram = [a, b, c]
        // abc = "a|b|c"
        // ab  = "a|b"
        let abc = ngram.joined(separator: "|")
        let ab = ngram.dropLast().joined(separator: "|")

        let c_abc_abc = getValueC_abc(abc) ?? 0
        let c_abx_ab  = getValueC_abx(ab) ?? 1
        let u_abx_ab  = getValueU_abx(ab) ?? 0

        // (count(abc) - d) / count(ab)
        let alpha = (Double(c_abc_abc) - d) / Double(c_abx_ab)
        // d * unique(ab) / count(ab)
        let gamma = d * Double(u_abx_ab) / Double(c_abx_ab)

        // 再帰呼び出し
        let prob = alpha + gamma * predict(Array(ngram.dropFirst()))
        predictCache[joinedKey] = prob
        return prob
    }
}

/// テキスト生成
public func generateText(inputText: String,
                         mixAlpha: Double,
                         lmBase: LM,
                         lmPerson: LM,
                         maxCount: Int = 100) -> String
{
    // もともとの文字列を配列化
    var chars = Array(inputText)
    // suffix を事前に取り出す
    var suffix = chars.suffix(lmBase.n - 1).map { String($0) }

    while chars.count < maxCount {
        var maxProb = -Double.infinity
        var nextWord = ""

        // 全候補を探索
        for w in lmBase.vocabSet {
            let pBase = lmBase.predict(suffix + [w])
            let pPerson = lmPerson.predict(suffix + [w])

            // どちらかが 0 ならスキップ
            if pBase == 0.0 || pPerson == 0.0 {
                continue
            }

            let mixLogProb = log2(pBase) + mixAlpha * (log2(pPerson) - log2(pBase))

            if mixLogProb > maxProb {
                maxProb = mixLogProb
                nextWord = w
            }
        }

        // 候補なし or EOS なら生成終了
        if nextWord.isEmpty || nextWord == lmBase.eos {
            break
        }

        // 1文字単位のモデルなら append で文字列に追加
        // (単語単位なら間にスペースを入れる等の工夫が必要)
        chars.append(contentsOf: nextWord)

        // suffix を更新
        suffix.append(nextWord)
        if suffix.count > (lmBase.n - 1) {
            suffix.removeFirst()
        }
    }
    return String(chars)
}
