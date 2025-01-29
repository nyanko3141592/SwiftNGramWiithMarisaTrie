//
//  Trainer.swift
//  SwiftNGram
//
//  Created by 高橋直希 on 2025/01/30.
//

import Foundation
import SwiftyMarisa

public class SwiftTrainer {
    let n: Int
    let bos: String = "<s>"
    let eos: String = "</s>"

    private var c_abc = [String: Int]()
    private var c_abx = [String: Int]()
    private var u_abx = [String: Int]()
    private var u_xbc = [String: Int]()
    private var u_xbx = [String: Int]()
    private var s_xbx = [String: Set<String>]()

    public init(n: Int) {
        self.n = n
    }

    private func countNGram(_ ngram: [String]) {
        guard ngram.count >= 2 else { return }

        let aBc = ngram.joined(separator: "|")
        let aB  = ngram.dropLast().joined(separator: "|")
        let Bc  = ngram.dropFirst().joined(separator: "|")
        let B   = ngram.dropFirst().dropLast().joined(separator: "|")
        let c   = ngram.last ?? ""

        c_abc[aBc, default: 0] += 1
        c_abx[aB, default: 0] += 1

        if c_abc[aBc] == 1 {
            u_abx[aB, default: 0] += 1
            u_xbc[Bc, default: 0] += 1
            u_xbx[B, default: 0
            ] += 1
        }
        s_xbx[B, default: []].insert(c)
    }

    public func countSent(_ sentence: [String]) {
        for k in 2...n {
            let padded = Array(repeating: bos, count: k - 1) + sentence + [eos]
            for i in 0..<(padded.count - k + 1) {
                let slice = Array(padded[i..<i+k])
                countNGram(slice)
            }
        }
    }

    private func makeVocab() -> [String] {
        let vocabPairs = c_abx.filter { $0.key.components(separatedBy: "|").count == 1 }
        return vocabPairs.sorted { $0.value > $1.value }.map { $0.key }
    }

    public func saveToMarisaTrie(baseFilename: String) {
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath

        let paths = [
            "\(baseFilename)_c_abc.marisa",
            "\(baseFilename)_c_abx.marisa",
            "\(baseFilename)_u_abx.marisa",
            "\(baseFilename)_u_xbc.marisa",
            "\(baseFilename)_u_xbx.marisa",
            "\(baseFilename)_r_xbx.marisa",
            "\(baseFilename)_vocab.marisa"
        ].map { file in
            URL(fileURLWithPath: currentDir).appendingPathComponent(file).path
        }

        let vocab = makeVocab()
        let vocabTrie = Marisa()
        vocabTrie.build { builder in
            for w in vocab {
                builder(w)
            }
        }
        vocabTrie.save(paths[6])
    }
}

