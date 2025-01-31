import Tokenizers
import Foundation

struct ZenzTokenizer {
    private let tokenizer: any Tokenizer
    init() async throws {
        self.tokenizer = try await AutoTokenizer.from(modelFolder: Bundle.module.resourceURL!.appendingPathComponent("tokenizer", isDirectory: true))
    }
    func encode(text: String) -> [Int] {
        return self.tokenizer.encode(text: text)
    }
    func decode(tokens: [Int]) -> String {
        return self.tokenizer.decode(tokens: tokens)
    }
    var vocabSize: Int {
        // FIXME
        6000
    }
}
