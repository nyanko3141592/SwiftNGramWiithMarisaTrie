//
//  TrainerTests.swift
//  SwiftNGram
//
//  Created by 高橋直希 on 2025/01/30.
//

import XCTest
@testable import SwiftNGram

final class TrainerTests: XCTestCase {
    func testTraining() {
        let trainer = Trainer(n: 3)
        trainer.trainFromFile(filePath: "train.txt")
        trainer.saveToMarisaTrie(baseFilename: "test")
        XCTAssertTrue(FileManager.default.fileExists(atPath: "test_c_abc.marisa"))
    }
}
