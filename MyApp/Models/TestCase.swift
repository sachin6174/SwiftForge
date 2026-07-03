import Foundation

public struct TestCase: Identifiable {
    public var id: Int { index }
    public let index: Int
    public let matrix: [[Character]]
    public let expected: Int
    public let name: String
    
    public init(index: Int, matrix: [[Character]], expected: Int, name: String) {
        self.index = index
        self.matrix = matrix
        self.expected = expected
        self.name = name
    }
}

public struct TestCaseResult: Identifiable {
    public let id = UUID()
    public let index: Int
    public let isPass: Bool
    public let name: String
    public let output: String
    public let expected: String
    public let time: String
    public let error: String?
    
    public init(index: Int, isPass: Bool, name: String, output: String, expected: String, time: String, error: String? = nil) {
        self.index = index
        self.isPass = isPass
        self.name = name
        self.output = output
        self.expected = expected
        self.time = time
        self.error = error
    }
}
