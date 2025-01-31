import Foundation
import SwiftyMarisa

/// Base64 でエンコードされた Key-Value をデコードする関数
func decodeKeyValue(_ foundString: String, key: String) -> UInt32? {
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
func getValue(from trie: Marisa, key: String) -> UInt32? {
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
    let d: Double

    let c_abc = Marisa()
    let c_abx = Marisa()
    let u_abx = Marisa()
    let u_xbc = Marisa()
    let u_xbx = Marisa()
    let r_xbx = Marisa()
    let vocabTrie = Marisa()
    public var vocabSet = Set<String>()

    public init?(baseFilename: String, n: Int, d: Double) {
        self.n = n
        self.d = d

        do {
            try c_abc.load("\(baseFilename)_c_abc.marisa")
            try c_abx.load("\(baseFilename)_c_abx.marisa")
            try u_abx.load("\(baseFilename)_u_abx.marisa")
            try u_xbc.load("\(baseFilename)_u_xbc.marisa")
            try u_xbx.load("\(baseFilename)_u_xbx.marisa")
            try r_xbx.load("\(baseFilename)_r_xbx.marisa")
            try vocabTrie.load("\(baseFilename)_vocab.marisa")
        } catch {
            return nil
        }

        vocabSet = Set(vocabTrie.search("", .predictive))
    }

    public func predict(_ ngram: [String]) -> Double {
        // ユニグラムの場合（再帰の終了条件）
        if ngram.count == 1 {
            let c = ngram[0]
            let c_abc_c = getValue(from: c_abc, key: c) ?? 0
            let total_tokens = getValue(from: c_abx, key: "") ?? 1  // 総トークン数
            return Double(c_abc_c) / Double(total_tokens)
        }

        let abc = ngram.joined(separator: "|")
        let ab = ngram.dropLast().joined(separator: "|")

        let c_abc_abc = getValue(from: c_abc, key: abc) ?? 0
        let c_abx_ab = getValue(from: c_abx, key: ab) ?? 1
        let u_abx_ab = getValue(from: u_abx, key: ab) ?? 0

        let alpha = (Double(c_abc_abc) - d) / Double(c_abx_ab)
        let gamma = d * Double(u_abx_ab) / Double(c_abx_ab)

        return alpha + gamma * predict(Array(ngram.dropFirst()))
    }
}

func generateText(inputText: String, mixAlpha: Double, lmBase: LM, lmPerson: LM, maxCount: Int = 100) -> String {
    var text = inputText
    while text.count < maxCount {
        var maxProb = -Double.infinity
        var nextWord = ""

        let suffix = Array(text.map { String($0) }.suffix(lmBase.n - 1))

        for w in lmBase.vocabSet {
            let pBase = lmBase.predict(suffix + [w])
            let pPerson = lmPerson.predict(suffix + [w])

            if pBase == 0.0 || pPerson == 0.0 {
                continue
            }

            let mixLogProb = log2(pBase) + mixAlpha * (log2(pPerson) - log2(pBase))

            if mixLogProb > maxProb {
                maxProb = mixLogProb
                nextWord = w
            }
        }

        if nextWord.isEmpty || nextWord == lmBase.eos { break }
        text += nextWord
    }
    return text
}
