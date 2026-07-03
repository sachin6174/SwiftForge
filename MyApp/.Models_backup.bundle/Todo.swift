import Foundation

public struct Todo: Codable, Identifiable {
    public let userId: Int
    public let id: Int
    public let title: String
    public let completed: Bool
    
    public init(userId: Int, id: Int, title: String, completed: Bool) {
        self.userId = userId
        self.id = id
        self.title = title
        self.completed = completed
    }
}

public struct SimulatedTodo: Identifiable {
    public let id = UUID()
    public let userId: Int
    public let todoId: Int
    public let title: String
    public let completed: Bool
    
    public init(userId: Int, todoId: Int, title: String, completed: Bool) {
        self.userId = userId
        self.todoId = todoId
        self.title = title
        self.completed = completed
    }
}
