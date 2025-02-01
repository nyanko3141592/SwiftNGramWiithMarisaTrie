import Foundation
import SwiftyMarisa

/// Base64 でエンコードされた Key-Value をデコードする関数
private func decodeKeyValue(_ suffix: some Collection<Int8>) -> UInt32? {
    // 最初の5個が値をエンコードしている
    let d = Int(Int8.max - 1)
    var value = 0
    for item in suffix.prefix(5) {
        value += Int(item) - 1
        value *= d
    }
    return UInt32(value)
}

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

    // 総トークン数 (ユニグラム計算用)
    private var totalTokens: UInt32

    private var tokenizer: ZenzTokenizer
    /// Trie から Key に対応する Value を取得する関数
    private func getValue(from trie: Marisa, key: [Int]) -> UInt32? {
        let int8s = SwiftTrainer.encodeKey(key: key) + [SwiftTrainer.keyValueDelimiter] // delimiter ( as it is negative, it must not appear in key part)
        let results = trie.search(int8s, .predictive)
        for result in results {
            if let decoded = decodeKeyValue(result.dropFirst(int8s.count)) {
                return decoded
            }
        }
        return nil
    }

    /// Trie から Key に対応する Value を取得する関数
    private func bulkGetValue(from trie: Marisa, prefix: [Int]) -> [Int: UInt32] {
        let int8s = SwiftTrainer.encodeKey(key: prefix) + [SwiftTrainer.predictiveDelimiter]  // 予測用のdelimiter
        let results = trie.search(int8s, .predictive)
        var dict = [Int: UInt32]()
        for result in results {
            var suffix = result.dropFirst(int8s.count)
            let v1 = suffix.removeFirst()
            let v2 = suffix.removeFirst()
            // delimiterを除去
            if suffix.first != SwiftTrainer.keyValueDelimiter {
                continue
            }
            suffix.removeFirst()
            if let decoded = decodeKeyValue(suffix) {
                let word = SwiftTrainer.decodeKey(v1: v1, v2: v2)
                dict[word] = decoded
            }
        }
        return dict
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
        self.totalTokens = self.getValue(from: c_abx, key: []) ?? 1// self.getValueC_abx([]) ?? 1
    }

    /// Kneser-Ney の確率を求める
    public func predict(
        _ ab: some BidirectionalCollection<Int>,
        nextWord: Int,
        c_abx_ab: UInt32,
        u_abx_ab: UInt32,
        c_abc_abc: UInt32,
        plf_items: [(
            u_xbc_abc_ab: [Int: UInt32],
            u_xbx_ab: UInt32?,
            r_xbx_ab: UInt32
        )]
    ) -> Double {
        // ngram = [a, b, c]
        // abc = "a|b|c"
        // ab  = "a|b"
        // (count(abc) - d) / count(ab)
        let alpha = (Double(c_abc_abc) - d) / Double(c_abx_ab)
        // d * unique(ab) / count(ab)
        let gamma = d * Double(u_abx_ab) / Double(c_abx_ab)

        // predict_lowerの処理
        var plf = 0.0
        var coef = 1.0
        for (u_xbc_abc_ab, u_xbx_ab, r_xbx_ab) in plf_items {
            // 第1項
            var alpha = 0.0
            if let u_xbx_ab {
                let u_xbc_abc = u_xbc_abc_ab[nextWord, default: 0]
                alpha = (Double(u_xbc_abc) - self.d) / Double(u_xbx_ab)
            }
            // 第2項
            var gamma = 1.0
            if let u_xbx_ab {
                gamma = self.d * Double(r_xbx_ab) / Double(u_xbx_ab)
            }
            plf += alpha * coef
            coef *= gamma
        }
        plf += coef / Double(self.tokenizer.vocabSize)

        let prob = alpha + gamma * plf
        return prob
    }

    /// Kneser-Ney の確率を求める
    public func bulkPredict(_ ngram: some BidirectionalCollection<Int>) -> [Double] {
        let ab = Array(ngram)
        let c_abx_ab  = self.getValue(from: c_abx, key: ab) ?? 1
        let u_abx_ab  = self.getValue(from: u_abx, key: ab) ?? 0
        let c_abc_abc = self.bulkGetValue(from: self.c_abc, prefix: ab)
        var u_xbc_abc: [(u_xbc_abc_ab: [Int: UInt32], u_xbx_ab: UInt32?, r_xbx_ab: UInt32)] = []
        for i in 1 ..< ngram.count {
            let ab = Array(ngram.dropFirst(i))
            let u_xbx_ab = self.getValue(from: self.u_xbx, key: ab)
            let r_xbx_ab = self.getValue(from: self.r_xbx, key: ab) ?? 1
            u_xbc_abc.append((u_xbc_abc_ab: self.bulkGetValue(from: self.u_xbc, prefix: ab), u_xbx_ab: u_xbx_ab, r_xbx_ab: r_xbx_ab))
        }
        // 全候補を探索
        var results = [Double]()
        results.reserveCapacity(tokenizer.vocabSize)
        for w in 0 ..< tokenizer.vocabSize {
            results.append(self.predict(ab, nextWord: w, c_abx_ab: c_abx_ab, u_abx_ab: u_abx_ab, c_abc_abc: c_abc_abc[w, default: 0], plf_items: u_xbc_abc))
        }
        return results
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
        let pBases = lmBase.bulkPredict(suffix)
        let pPersons = lmPerson.bulkPredict(suffix)
        for (w, (pBase, pPerson)) in zip(pBases, pPersons).enumerated() {
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
