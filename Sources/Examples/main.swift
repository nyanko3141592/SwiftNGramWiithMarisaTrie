//
//  main.swift
//  SwiftNGram
//
//  Created by 高橋直希 on 2025/01/31.
//

import SwiftNGram
import Foundation

func measureExecutionTime(block: () -> String) -> (String, Double) {
    let start = DispatchTime.now()
    let result = block()
    let end = DispatchTime.now()
    let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
    let milliTime = Double(nanoTime) / 1_000_000 // ミリ秒単位
    return (result, milliTime)
}

func inference() async {
    let baseFilename = "/Users/takahashinaoki/Dev/projects/mitou/SwiftNGram/marisa/lm"
    print("Loading LM base: \(baseFilename)")
    guard let lmBase = LM(baseFilename: baseFilename, n: 5, d: 0.75) else {
        print("[Error] Failed to load LM base")
        return
    }
    guard let lmPerson = LM(baseFilename: baseFilename, n: 5, d: 0.75) else {
        print("[Error] Failed to load LM person")
        return
    }
    let tokenizer = await ZenzTokenizer()

    let alphaList: [Double] = [0.1, 0.3, 0.5, 0.7, 0.9]

    for mixAlpha in alphaList {
        let inputText = "彼は"

        // 時間計測
        let (generatedText, elapsedTime) = measureExecutionTime {
            generateText(inputText: inputText, mixAlpha: mixAlpha, lmBase: lmBase, lmPerson: lmPerson, tokenizer: tokenizer, maxCount: 20)
        }

        print("alpha = \(mixAlpha): \(generatedText)")
        print("Execution Time: \(elapsedTime) ms")
    }
}


func runExample() async {
    let trainFilePath = "/Users/miwa/Desktop/SwiftNGramWiithMarisaTrie/train.txt"
    let modelBase = "lm"
    let ngramSize = 5

    print("=== Training Model ===")
    await trainNGramFromFile(filePath: trainFilePath, n: ngramSize, baseFilename: modelBase)

    print("=== Loading Model for Inference ===")
    await inference()
}   

await runExample()
