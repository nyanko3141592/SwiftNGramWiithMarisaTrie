//
//  main.swift
//  SwiftNGram
//
//  Created by 高橋直希 on 2025/01/31.
//

import SwiftNGram
import Foundation


func inference(){
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

func runExample() {
    let trainFilePath = "/Users/takahashinaoki/Dev/projects/mitou/SwiftNGram/train.txt"
    let modelBase = "lm"
    let ngramSize = 5

    print("=== Training Model ===")
    trainNGramFromFile(filePath: trainFilePath, n: ngramSize, baseFilename: modelBase)

    print("=== Loading Model for Inference ===")
    inference()
}   

runExample()
