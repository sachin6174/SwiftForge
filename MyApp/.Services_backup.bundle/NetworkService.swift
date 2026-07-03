import Foundation

public protocol NetworkServiceProtocol {
    func fetchTodo(id: Int) async throws -> Todo
}

public class NetworkService: NetworkServiceProtocol {
    public init() {}
    
    public func fetchTodo(id: Int) async throws -> Todo {
        let urlString = "https://jsonplaceholder.typicode.com/todos/\(id)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(Todo.self, from: data)
    }
}
