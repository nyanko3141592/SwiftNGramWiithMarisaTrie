
import Foundation
import SwiftNGram

func main() {
    let inputFilePath = "train.txt"   // テキストデータファイル
    let outputBase = "lm"             // 学習データの保存先
    let ngramSize = 5                 // 5-gram

    // 🔹 NGram学習
    let trainer = Trainer(n: ngramSize)
    trainer.trainFromFile(filePath: inputFilePath)
    trainer.saveToMarisaTrie(baseFilename: outputBase)

    // 🔹 推論の実行
    guard let inference = Inference(marisaFile: "\(outputBase)_c_abc.marisa") else {
        print("[Error] 推論モデルのロードに失敗しました")
        return
    }

    var text = "彼は"
    while text.count < 100 {
        let suffix = Array(text.map { String($0) }.suffix(ngramSize - 1))
        guard let nextWord = inference.predictNextWord(ngram: suffix) else {
            break
        }
        if nextWord == "</s>" { break }
        text += nextWord
    }
    print("Generated text: \(text)")
}

main()
