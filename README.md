# 実行

swift build
swift run SwiftNGramExample

# 再現する挙動

```
/// 実行サンプル
func trainRun() {
    let inputFilePath = "/Users/takahashinaoki/Dev/projects/SwiftNGram/train.txt"       // 実際のコーパスファイルパス
    let outputBase    = "lm"       // 出力先のファイル名基盤
    let ngramSize     = 5

    trainNGramFromFile(filePath: inputFilePath, n: ngramSize, baseFilename: outputBase)
}


func inference(){
    let baseFilename = "/Users/takahashinaoki/Library/Developer/Xcode/DerivedData/marisaTrieSwift1-dtcfophyfagzztcqoteojmoaketz/Build/Products/Debug/lm"
    guard let lmBase = LM(baseFilename: baseFilename, n: 5, d: 0.75) else {
        print("[Error] Failed to load LM base")
        return
    }
    guard let lmPerson = LM(baseFilename: baseFilename, n: 5, d: 0.75) else {
        print("[Error] Failed to load LM person")
        return
    }

    let alphaList: [Double] = [0.1, 0.3, 0.5, 0.7, 0.9]

    for mixAlpha in alphaList {
        var text = "彼は"
        while text.count < 100 {
            var maxProb = -Double.infinity
            var nextWord = ""

            let suffix = Array(text.map { String($0) }.suffix(lmBase.n - 1))

            for w in lmBase.vocabSet {
                let pBase = lmBase.predict(suffix + [w])
                let pPerson = lmPerson.predict(suffix + [w])

                // `pBase` や `pPerson` が 0.0 にならないようチェック
                if pBase == 0.0 || pPerson == 0.0 {
                    continue
                }

                let mixLogProb = log2(pBase) + mixAlpha * (log2(pPerson) - log2(pBase))

                if mixLogProb > maxProb {
                    maxProb = mixLogProb
                    nextWord = w
                }
            }

            if nextWord.isEmpty {
                break
            }

            if nextWord == lmBase.eos { break }
            text += nextWord
        }
        print("alpha = \(mixAlpha): \(text)")
    }

}


func main() {
    trainRun()
    inference()
}

main()

```
