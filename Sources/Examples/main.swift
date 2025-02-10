//
//  main.swift
//  SwiftNGram
//
//  Created by 高橋直希 on 2025/01/31.
//

import SwiftNGram
import Foundation

/// 実行時間を測定するヘルパー関数
func measureExecutionTime(block: () -> String) -> (String, Double) {
    let start = DispatchTime.now()
    let result = block()
    let end = DispatchTime.now()
    let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
    let milliTime = Double(nanoTime) / 1_000_000 // ミリ秒単位
    return (result, milliTime)
}

/// 推論を行う関数（モデルの読み込み時に baseFilename を指定できるように変更）
func inference(modelName: String) {
    let baseFilename = "/Users/takahashinaoki/Library/Application Support/SwiftNGram/marisa/\(modelName)"
    print("Loading LM base: \(baseFilename)")
    let tokenizer = ZenzTokenizer()
    let lmBase = LM(baseFilename: baseFilename, n: 5, d: 0.75, tokenizer: tokenizer)
    let lmPerson = LM(baseFilename: baseFilename, n: 5, d: 0.75, tokenizer: tokenizer)

    let alphaList: [Double] = [0.1, 0.3, 0.5, 0.7, 0.9]
    for mixAlpha in alphaList {
        let inputText = "彼"

        // 推論処理の実行と時間計測
        let (generatedText, elapsedTime) = measureExecutionTime {
            generateText(
                inputText: inputText,
                mixAlpha: mixAlpha,
                lmBase: lmBase,
                lmPerson: lmPerson,
                tokenizer: tokenizer,
                maxCount: 20
            )
        }
        print("alpha = \(mixAlpha): \(generatedText)")
        print("Execution Time: \(elapsedTime) ms")
    }
}

/// サンプル実行：初回学習、追加学習（インクリメンタルトレーニング）、まとめて学習の推論結果を比較する
func runExample() {
    let trainFilePath = "/Users/takahashinaoki/Dev/projects/mitou/SwiftNGram/train.txt"
    let modelBaseIncremental = "lm"            // インクリメンタルトレーニング用のモデル名
    let modelBaseCombined = "lm_combined"        // まとめて学習用のモデル名
    let ngramSize = 5

    // ----- ① 初回学習（学習ファイルのみ） -----
    print("=== [Step 1] Initial Training (File Only) ===")
    trainNGramFromFile(filePath: trainFilePath, n: ngramSize, baseFilename: modelBaseIncremental)

    print("=== [Step 2] Inference After Initial Training ===")
    inference(modelName: modelBaseIncremental)

    // ----- ② 追加学習（インクリメンタルトレーニング） -----
    let additionalSentences = [
        "今日はいい天気ですね。",
        "新しいプロジェクトに取り組んでいる。",
        "Swiftでのプログラミングはとても楽しい。",
        "この言語モデルは追加学習によって改善されます。"
    ]

    print("=== [Step 3] Incremental Training with Additional Sentences ===")
    incrementalTrainNGram(lines: additionalSentences, n: ngramSize, baseFilename: modelBaseIncremental)

    print("=== [Step 4] Inference After Incremental Training ===")
    inference(modelName: modelBaseIncremental)

    // ----- ③ まとめて学習（ファイルのテキスト＋追加文章） -----
    print("=== [Step 5] Combined Training: File Text + Additional Sentences ===")
    // 学習ファイルの各行を読み込む
    guard let baseFileLines = readLinesFromFile(filePath: trainFilePath) else {
        print("エラー：学習ファイルを読み込めませんでした。")
        return
    }
    // ファイル内テキストと追加文章を結合する
    let combinedLines = baseFileLines + additionalSentences
    trainNGram(lines: combinedLines, n: ngramSize, baseFilename: modelBaseCombined)

    print("=== [Step 6] Inference After Combined Training ===")
    inference(modelName: modelBaseCombined)
}

runExample()
