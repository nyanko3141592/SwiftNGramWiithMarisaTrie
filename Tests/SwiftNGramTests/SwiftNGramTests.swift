import XCTest
@testable import SwiftNGram

class SwiftNGramTests: XCTestCase {
    func testInferencePerformance() {
        let baseFilename = "/Users/takahashinaoki/Dev/projects/mitou/SwiftNGram/marisa/lm"

        guard let lmBase = LM(baseFilename: baseFilename, n: 5, d: 0.75) else {
            XCTFail("[Error] Failed to load LM base")
            return
        }
        guard let lmPerson = LM(baseFilename: baseFilename, n: 5, d: 0.75) else {
            XCTFail("[Error] Failed to load LM person")
            return
        }

        let alphaList: [Double] = [0.9]
        let alpha = alphaList[0]
        let texts = ["彼は", "先生", "今度", "墓", "それは"]

        for inputText in texts {
            // 時間計測
            let generatedText = generateText(inputText: inputText, mixAlpha: alpha, lmBase: lmBase, lmPerson: lmPerson, maxCount: 20)

            print("alpha = \(alpha): \(generatedText)")
        }
    }
}
