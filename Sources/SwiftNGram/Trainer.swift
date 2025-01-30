//
//  Trainer.swift
//  SwiftNGram
//
//  Created by 高橋直希 on 2025/01/30.
//
import Foundation
import SwiftyMarisa

public class Trainer {
    let n: Int
    private var c_abc = [String: Int]()

    public init(n: Int) {
        self.n = n
    }

    public func trainFromFile(filePath: String) {
        guard let data = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            print("[Error] Could not read file: \(filePath)")
            return
        }

        let lines = data.split(separator: "\n")
        for line in lines {
            let tokens = Array(line.trimmingCharacters(in: .whitespacesAndNewlines)).map { String($0) }
            if tokens.count > 1 {
                let key = tokens.joined(separator: "|")
                c_abc[key, default: 0] += 1
            }
        }
    }

    public func saveToMarisaTrie(baseFilename: String) {
        let trie = Marisa()
        trie.build { builder in
            for (key, value) in c_abc {
                builder("\(key)@\(value)")
            }
        }
        trie.save("\(baseFilename)_c_abc.marisa")
    }
}
