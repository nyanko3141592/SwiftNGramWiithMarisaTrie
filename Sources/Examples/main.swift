//
//  main.swift
//  SwiftNGram
//
//  Created by 高橋直希 on 2025/01/31.
//

import SwiftNGram
import Foundation


func inference(){
}

func runExample() {
    let trainFilePath = "train.txt"
    let modelBase = "lm"
    let testText = "彼は"

    print("=== Training Model ===")
    trainNGramFromFile(filePath: trainFilePath, n: 5, baseDirectory: "/Users/takahashinaoki/Dev/projects/mitou/SwiftNGram/marisa", baseFilename: modelBase)

    print("=== Loading Model for Inference ===")

}

runExample()
