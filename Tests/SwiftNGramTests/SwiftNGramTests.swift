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
        let inputText = "彼は"

        for mixAlpha in alphaList {
            let generatedText = generateText(inputText: inputText, mixAlpha: mixAlpha, lmBase: lmBase, lmPerson: lmPerson)
            XCTAssertFalse(generatedText.isEmpty, "Generated text should not be empty")
            print("Alpha \(mixAlpha): Generated text = \(generatedText)")
        }
    }

    func testTokenizers() async throws {
        let tokenizer = try await ZenzTokenizer()
        let inputIds = tokenizer.encode(text: "これは日本語です")
        XCTAssertEqual(inputIds, [268, 262, 253, 304, 358, 698, 246, 255])
        XCTAssertEqual(tokenizer.decode(tokens: inputIds), "これは日本語です")
    }
}
