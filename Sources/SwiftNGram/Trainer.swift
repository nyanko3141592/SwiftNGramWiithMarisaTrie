//
//  Trainer.swift
//  SwiftNGram
//
//  Created by 高橋直希 on 2025/01/30.
//

import Foundation
import SwiftyMarisa

class SwiftTrainer {
    let n: Int
    let bos: String = "<s>"
    let eos: String = "</s>"

    /// Python の defaultdict(int) 相当
    private var c_abc = [String: Int]()
    private var c_abx = [String: Int]()
    private var u_abx = [String: Int]()
    private var u_xbc = [String: Int]()
    private var u_xbx = [String: Int]()
    /// Python の defaultdict(set) 相当
    private var s_xbx = [String: Set<String>]()

    init(n: Int) {
        self.n = n
    }

    /// 単一 n-gram (abc など) をカウント
    /// Python の count_ngram に対応
    private func countNGram(_ ngram: [String]) {
        // n-gram は最低 2 token 必要 (式的に aB, Bc, B, c のような分割を行う)
        guard ngram.count >= 2 else { return }

        let aBc = ngram.joined(separator: "|")             // abc
        let aB  = ngram.dropLast().joined(separator: "|")  // ab
        let Bc  = ngram.dropFirst().joined(separator: "|") // bc
        // 中央部分 B, 末尾単語 c
        let B   = ngram.dropFirst().dropLast().joined(separator: "|")
        let c   = ngram.last ?? ""

        // C(abc)
        c_abc[aBc, default: 0] += 1
        // C(ab・)
        c_abx[aB,   default: 0] += 1

        // 初回登場なら U(...) を更新
        if c_abc[aBc] == 1 {
            // U(ab・)
            u_abx[aB, default: 0] += 1
            // U(・bc)
            u_xbc[Bc, default: 0] += 1
            // U(・b・)
            u_xbx[B, default: 0] += 1
        }
        // s_xbx[B] = s_xbx[B] ∪ {c}
        s_xbx[B, default: []].insert(c)
    }

    /// 文から n-gram をカウント
    /// Python の count_sent_ngram に対応
    private func countSentNGram(n: Int, sent: [String]) {
        // 先頭に (n-1) 個の <s>、末尾に </s> を追加
        let padded = Array(repeating: bos, count: n - 1) + sent + [eos]
        // スライディングウィンドウで n 個ずつ
        for i in 0..<(padded.count - n + 1) {
            let slice = Array(padded[i..<i+n])
            countNGram(slice)
        }
    }

    /// 文全体をカウント (2-gram～N-gram までをまとめて処理)
    /// Python の count_sent に対応
    func countSent(_ sentence: [String]) {
        for k in 2...n {
            countSentNGram(n: k, sent: sentence)
        }
    }

    /// Python の make_vocab 相当
    /// c_abx のうち、トークン (単一語) のみを取り出して頻度順にソート
    private func makeVocab() -> [String] {
        // c_abx の key が "単一語" か判定
        // → "key.split('|').count == 1" 相当
        let vocabPairs = c_abx.filter { (k, _) in
            k.components(separatedBy: "|").count == 1
        }

        // 頻度でソート (降順)
        let sorted = vocabPairs.sorted { $0.value > $1.value }
        return sorted.map { $0.key }
    }

    /// 文字列 + 4バイト整数を Base64 にエンコードした文字列を作る
    /// Python の encode_key_value(key, value) 相当
    private func encodeKeyValue(key: String, value: Int) -> String {
        // 32bit 小端エンディアンに変換
        // ※ 頻度が 2^31 超える可能性があるなら要検討
        let val32 = UInt32(truncatingIfNeeded: value).littleEndian
        var data = withUnsafeBytes(of: val32) { Data($0) }
        // Base64 エンコード
        let b64 = data.base64EncodedString()
        // ここではデリミタを "@" とする
        return "\(key)@\(b64)"
    }

    /// 指定した [String: Int] を Trie に登録して保存
    private func buildAndSaveTrie(from dict: [String: Int], to path: String) {
        let encodedStrings: [String] = dict.map { (k, v) in
            encodeKeyValue(key: k, value: v)
        }

        let trie = Marisa()
        trie.build { builder in
            for entry in encodedStrings {
                builder(entry)
            }
        }
        trie.save(path)
        print("Saved \(path): \(encodedStrings.count) entries")
    }


    /// 上記のカウント結果を marisa ファイルとして保存
    func saveToMarisaTrie(baseFilename: String) {
       let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath  // カレントディレクトリの取得
        
        // marisa ディレクトリの作成
        let marisaDir = URL(fileURLWithPath: currentDir).appendingPathComponent("marisa")
        do {
            try fileManager.createDirectory(
                at: marisaDir,
                withIntermediateDirectories: true,  // 中間ディレクトリも作成
                attributes: nil
            )
        } catch {
            print("ディレクトリ作成エラー: \(error)")
            return
        }
        
        // ファイルパスの生成（marisa ディレクトリ内に配置）
        let paths = [
            "\(baseFilename)_c_abc.marisa",
            "\(baseFilename)_c_abx.marisa",
            "\(baseFilename)_u_abx.marisa",
            "\(baseFilename)_u_xbc.marisa",
            "\(baseFilename)_u_xbx.marisa",
            "\(baseFilename)_r_xbx.marisa",
            "\(baseFilename)_vocab.marisa"
        ].map { file in
            marisaDir.appendingPathComponent(file).path
        }

        // c_abc
        buildAndSaveTrie(from: c_abc, to: paths[0])
        // c_abx
        buildAndSaveTrie(from: c_abx, to: paths[1])
        // u_abx
        buildAndSaveTrie(from: u_abx, to: paths[2])
        // u_xbc
        buildAndSaveTrie(from: u_xbc, to: paths[3])
        // u_xbx
        buildAndSaveTrie(from: u_xbx, to: paths[4])

        // s_xbx は key: String, val: Set<String> なので、val は要素数のみ登録する
        let r_xbx: [String: Int] = s_xbx.mapValues { $0.count }
        buildAndSaveTrie(from: r_xbx, to: paths[5])

        // vocab は key そのものを登録（値は持たない）
        let vocab = makeVocab()
        let vocabTrie = Marisa()
        vocabTrie.build { builder in
            for w in vocab {
                builder(w)
            }
        }
        vocabTrie.save(paths[6])
        print("Saved \(paths[6]): \(vocab.count) entries")

        // **絶対パスでの出力**
        print("All saved files (absolute paths):")
        for path in paths {
            print(path)
        }
    }

}

/// 実行例として、テキストファイルを読み込んで n-gram をカウントし、
/// Marisa-Trie を保存する関数
public func trainNGramFromFile(
    filePath: String,
    n: Int,
    baseFilename: String
) {
    let trainer = SwiftTrainer(n: n)

    // ファイルの内容を 1 行ずつ読み込み
    guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
        print("[Error] ファイルを開けませんでした: \(filePath)")
        return
    }
    defer {
        try? fileHandle.close()
    }

    // UTF-8 で行単位に読み込む
    let data = fileHandle.readDataToEndOfFile()
    guard let text = String(data: data, encoding: .utf8) else {
        print("[Error] UTF-8 で読み込めませんでした: \(filePath)")
        return
    }

    let lines = text.components(separatedBy: .newlines)

    // 各行に対して n-gram カウント
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        // Python 版は「文字単位」で取り出していたが、
        // 必要に応じて単語単位で分割するならこちらを修正
        let tokens = Array(trimmed).map { String($0) }
        if !tokens.isEmpty {
            trainer.countSent(tokens)
        }
    }

    // 最後に Trie ファイルを保存
    trainer.saveToMarisaTrie(baseFilename: baseFilename)
}