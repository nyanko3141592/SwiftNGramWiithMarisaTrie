import XCTest
@testable import SwiftNGram
import Tokenizers

class SwiftNGramTests: XCTestCase {
    func testInferencePerformance() {
        let tokenizer = ZenzTokenizer()
        let baseFilename = "/Users/miwa/Library/Developer/Xcode/DerivedData/SwiftNGramWiithMarisaTrie-hkjbiyuowxntzafhkszomslvnsmq/Build/Products/Debug/marisa/lm"

        let lmBase = LM(baseFilename: baseFilename, n: 5, d: 0.75, tokenizer: tokenizer)
        let lmPerson = LM(baseFilename: baseFilename, n: 5, d: 0.75, tokenizer: tokenizer)

        let alphaList: [Double] = [0.9]
        let inputText = "ザーサイと"

        for mixAlpha in alphaList {
            let generatedText = generateText(inputText: inputText, mixAlpha: mixAlpha, lmBase: lmBase, lmPerson: lmPerson, tokenizer: tokenizer)
            XCTAssertFalse(generatedText.isEmpty, "Generated text should not be empty")
            print("Alpha \(mixAlpha): Generated text = \(generatedText)")
        }
    }

    func testPredictPerformance() {
        let baseFilename = "/Users/miwa/Library/Developer/Xcode/DerivedData/SwiftNGramWiithMarisaTrie-hkjbiyuowxntzafhkszomslvnsmq/Build/Products/Debug/marisa/lm"

        let tokenizer = ZenzTokenizer()
        let lmBase = LM(baseFilename: baseFilename, n: 5, d: 0.75, tokenizer: tokenizer)
        let lmPerson = LM(baseFilename: baseFilename, n: 5, d: 0.75, tokenizer: tokenizer)

        let alphaList: [Double] = [0.9]
        let inputText = "元号はいつ"

        for _ in 0 ..< 1000 {
            for mixAlpha in alphaList {
                let generatedText = generateText(inputText: inputText, mixAlpha: mixAlpha, lmBase: lmBase, lmPerson: lmPerson, tokenizer: tokenizer, maxCount: 6)
                XCTAssertFalse(generatedText.isEmpty, "Generated text should not be empty")
                print("Alpha \(mixAlpha): Generated text = \(generatedText)")
            }
        }
    }

    func testBulkPredict() {
        let baseFilename = "/Users/miwa/Library/Application Support/SwiftNGram/marisa/lm"

        let tokenizer = ZenzTokenizer()
        let lmBase = LM(baseFilename: baseFilename, n: 5, d: 0.75, tokenizer: tokenizer)
        let results = lmBase.bulkPredict(tokenizer.encode(text: "これは"))
        XCTAssertEqual(results.reduce(into: 0) {$0 += $1}, 1.0, accuracy: 0.0001)
        XCTAssertTrue(results.allSatisfy{ $0 >= 0.0})
        print(results.filter{$0 > 0.0})
    }

    func testTokenizers() throws {
        let tokenizer = ZenzTokenizer()
        let inputIds = tokenizer.encode(text: "これは日本語です")
        XCTAssertEqual(inputIds, [268, 262, 253, 304, 358, 698, 246, 255])
        XCTAssertEqual(tokenizer.decode(tokens: inputIds), "これは日本語です")
    }
}
