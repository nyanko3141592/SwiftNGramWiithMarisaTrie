import Foundation
import SwiftyMarisa

/// Base64 でエンコードされた Key-Value をデコードする関数
private func decodeKeyValue(_ foundString: [Int8], key: [Int8]) -> UInt32? {
    let suffix = Array(foundString.dropFirst(key.count))
//    print(foundString, key, suffix)
    let base64value = String(decoding: suffix.map { UInt8($0)}, as: UTF8.self)
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

///// Base64 でエンコードされた Key-Value をデコードする関数
//private func decodeKeyValue(_ foundString: [Int8], key: [Int8]) -> UInt32? {
//    let suffix = Array(foundString.dropFirst(key.count))
//    guard suffix.count == 4 else {
//        return nil
//    }
//    return suffix.withUnsafeBytes { rawBuffer in
//        rawBuffer.load(as: UInt32.self).littleEndian
//    }
//}

/// Kneser-Ney 言語モデル
public class LM {
    public let n: Int
    public let d: Double

    // Tries
    let c_abc: Marisa
    let c_abx: Marisa
    let u_abx: Marisa
    let u_xbc: Marisa
    let u_xbx: Marisa
    let r_xbx: Marisa
    let vocabTrie: Marisa

    // キャッシュ
    private var predictCache: [[Int]: Double]
    private var c_abcCache: [[Int]: UInt32?]
    private var c_abxCache: [[Int]: UInt32?]
    private var u_abxCache: [[Int]: UInt32?]
    private var u_xbcCache: [[Int]: UInt32?]
    private var u_xbxCache: [[Int]: UInt32?]
    private var r_xbxCache: [[Int]: UInt32?]

    // 総トークン数 (ユニグラム計算用)
    private var totalTokens: UInt32

    private var tokenizer: ZenzTokenizer
    /// Trie から Key に対応する Value を取得する関数
    private func getValue(from trie: Marisa, key: [Int]) -> UInt32? {
        let int8s = SwiftTrainer.encodeKey(key: key) + [Int8.min] // delimiter ( as it is negative, it must not appear in key part)
        let results = trie.search(int8s, .predictive)
        for result in results {
            if let decoded = decodeKeyValue(result, key: int8s) {
                return decoded
            }
        }
        return nil
    }

    public init?(baseFilename: String, n: Int, d: Double, tokenizer: ZenzTokenizer) {
        self.tokenizer = tokenizer
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

        self.predictCache = [:]
        self.c_abcCache = [:]
        self.c_abxCache = [:]
        self.u_abxCache = [:]
        self.u_xbcCache = [:]
        self.u_xbxCache = [:]
        self.r_xbxCache = [:]

        self.totalTokens = 0

        c_abc.load("\(baseFilename)_c_abc.marisa")
        c_abx.load("\(baseFilename)_c_abx.marisa")
        u_abx.load("\(baseFilename)_u_abx.marisa")
        u_xbc.load("\(baseFilename)_u_xbc.marisa")
        u_xbx.load("\(baseFilename)_u_xbx.marisa")
        r_xbx.load("\(baseFilename)_r_xbx.marisa")
        vocabTrie.load("\(baseFilename)_vocab.marisa")

        // 全てのストアドプロパティに仮の値が入ったので、ここから初めて self のメソッドを呼べる
        // totalTokens の最終値をセット
        self.totalTokens = self.getValueC_abx([]) ?? 1
    }

    private func getValueC_abc(_ key: [Int]) -> UInt32? {
        if let cached = c_abcCache[key] {
            return cached
        }
        let val = getValue(from: c_abc, key: key)
        c_abcCache[key] = val
        return val
    }

    private func getValueC_abx(_ key: [Int]) -> UInt32? {
        if let cached = c_abxCache[key] {
            return cached
        }
        let val = getValue(from: c_abx, key: key)
        c_abxCache[key] = val
        return val
    }

    private func getValueU_abx(_ key: [Int]) -> UInt32? {
        if let cached = u_abxCache[key] {
            return cached
        }
        let val = getValue(from: u_abx, key: key)
        u_abxCache[key] = val
        return val
    }

    private func getValueU_xbc(_ key: [Int]) -> UInt32? {
        if let cached = u_xbcCache[key] {
            return cached
        }
        let val = getValue(from: u_xbc, key: key)
        u_xbcCache[key] = val
        return val
    }

    private func getValueU_xbx(_ key: [Int]) -> UInt32? {
        if let cached = u_xbxCache[key] {
            return cached
        }
        let val = getValue(from: u_xbx, key: key)
        u_xbxCache[key] = val
        return val
    }

    private func getValueR_xbx(_ key: [Int]) -> UInt32? {
        if let cached = r_xbxCache[key] {
            return cached
        }
        let val = getValue(from: r_xbx, key: key)
        r_xbxCache[key] = val
        return val
    }

    /// Kneser-Ney の確率を求める
    public func predict(_ ngram: some BidirectionalCollection<Int>, nextWord: Int) -> Double {
        // キャッシュにある場合は即返す
        // ngram = [a, b, c]
        // abc = "a|b|c"
        // ab  = "a|b"
        let ab = Array(ngram)
        let c = [nextWord]
        let abc = ab + c
        if let cached = predictCache[abc] {
            return cached
        }

        // ユニグラムの場合（再帰の終了条件）
        if ngram.count == 0 {
            let c_abc_c = getValueC_abc(c) ?? 0
            let prob = Double(c_abc_c) / Double(totalTokens)
            predictCache[abc] = prob
            return prob
        }

        let c_abc_abc = getValueC_abc(abc) ?? 0
        let c_abx_ab  = getValueC_abx(ab) ?? 1
        let u_abx_ab  = getValueU_abx(ab) ?? 0

        // (count(abc) - d) / count(ab)
        let alpha = (Double(c_abc_abc) - d) / Double(c_abx_ab)
        // d * unique(ab) / count(ab)
        let gamma = d * Double(u_abx_ab) / Double(c_abx_ab)

        // 再帰呼び出し
        let prob = alpha + gamma * self.predict(ngram.dropFirst(), nextWord: nextWord)
        predictCache[abc] = prob
        return prob
    }
}

/// テキスト生成
public func generateText(
    inputText: String,
    mixAlpha: Double,
    lmBase: LM,
    lmPerson: LM,
    tokenizer: ZenzTokenizer,
    maxCount: Int = 100
) -> String
{
    // もともとの文字列を配列化
    var tokens = tokenizer.encode(text: inputText)
    // suffix を事前に取り出す
    var suffix = tokens.suffix(lmBase.n - 1)

    while tokens.count < maxCount {
        var maxProb = -Double.infinity
        var nextWord = -1

        // 全候補を探索
        for w in 0 ..< tokenizer.vocabSize {
            let pBase = lmBase.predict(suffix, nextWord: w)
            let pPerson = lmPerson.predict(suffix, nextWord: w)
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
        if nextWord == -1 || nextWord == tokenizer.endTokenID {
            break
        }

        // 1文字単位のモデルなら append で文字列に追加
        // (単語単位なら間にスペースを入れる等の工夫が必要)
        tokens.append(nextWord)

        // suffix を更新
        suffix.append(nextWord)
        if suffix.count > (lmBase.n - 1) {
            suffix.removeFirst()
        }
    }
    return tokenizer.decode(tokens: tokens)
}
