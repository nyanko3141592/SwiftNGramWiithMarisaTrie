import Tokenizers
import Foundation

public struct ZenzTokenizer {
    private let tokenizer: any Tokenizer
    public init() async {
        self.tokenizer = try! await AutoTokenizer.from(modelFolder: Bundle.module.resourceURL!.appendingPathComponent("tokenizer", isDirectory: true))
    }
    func encode(text: String) -> [Int] {
        return self.tokenizer.encode(text: text)
    }
    func decode(tokens: [Int]) -> String {
        return self.tokenizer.decode(tokens: tokens)
    }
    var startTokenID: Int {
        self.tokenizer.bosTokenId!
    }
    var endTokenID: Int {
        self.tokenizer.eosTokenId!
    }
    var vocabSize: Int {
        // FIXME
        6000
    }
}
