//
//  Inference.swift
//  SwiftNGram
//
//  Created by 高橋直希 on 2025/01/30.
//
import Foundation
import SwiftyMarisa

public class Inference {
    private let trie: Marisa

    public init?(marisaFile: String) {
        trie = Marisa()
        trie.load(marisaFile)
    }

    public func predictNextWord(ngram: [String]) -> String? {
        let prefix = ngram.joined(separator: "|")
        let results = trie.search(prefix, .predictive)
        return Array(results).first
    }
}
