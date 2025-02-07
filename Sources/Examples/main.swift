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

func inference() {
    let baseFilename = "/Users/miwa/Library/Developer/Xcode/DerivedData/SwiftNGramWiithMarisaTrie-hkjbiyuowxntzafhkszomslvnsmq/Build/Products/Debug/marisa/lm"
    print("Loading LM base: \(baseFilename)")
    let tokenizer = ZenzTokenizer()
    let lmBase = LM(baseFilename: baseFilename, n: 5, d: 0.75, tokenizer: tokenizer)
    let lmPerson = LM(baseFilename: baseFilename, n: 5, d: 0.75, tokenizer: tokenizer)

    let alphaList: [Double] = [0.1, 0.3, 0.5, 0.7, 0.9]

    for mixAlpha in alphaList {
        let inputText = "元号"

        // 時間計測
        let (generatedText, elapsedTime) = measureExecutionTime {
            generateText(inputText: inputText, mixAlpha: mixAlpha, lmBase: lmBase, lmPerson: lmPerson, tokenizer: tokenizer, maxCount: 20)
        }

        print("alpha = \(mixAlpha): \(generatedText)")
        print("Execution Time: \(elapsedTime) ms")
    }
}

func runExample() {
//    let trainFilePath = "/Users/miwa/Desktop/SwiftNGramWiithMarisaTrie/train.txt"
//    let trainFilePath = "/Users/miwa/Desktop/n-gram/texts.txt"
    let trainFilePath = "/Users/miwa/Downloads/marisa-base/all_texts"
    let modelBase = "lm"
    let ngramSize = 5

    print("=== Training Model ===")
    trainNGramFromFile(filePath: trainFilePath, n: ngramSize, baseFilename: modelBase)

    print("=== Loading Model for Inference ===")
    inference()
}   

runExample()
