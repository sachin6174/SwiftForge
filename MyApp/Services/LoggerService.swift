import Foundation

public protocol LoggerServiceProtocol {
    func log(_ message: String, level: LogLevel)
    func getLogFilePath() -> String
    func clearLogs()
}

public enum LogLevel: String {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case success = "SUCCESS"
}

public class LoggerService: LoggerServiceProtocol {
    public static let shared = LoggerService()
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.swiftforge.logger", qos: .utility)
    
    public var logFileUrl: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("swiftforge_execution.log")
    }
    
    public var workspaceLogUrl: URL {
        return URL(fileURLWithPath: "/Users/sachinkumar/Desktop/Untitled Project/app_test.log")
    }
    
    public init() {}
    
    public func log(_ message: String, level: LogLevel = .info) {
        queue.async {
            let timestamp = Self.dateFormatter.string(from: Date())
            let logLine = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
            
            // Print to stdout
            print(logLine, terminator: "")
            
            // Append to primary log file in Documents
            self.appendString(logLine, to: self.logFileUrl)
            
            // Append to workspace app_test.log file
            self.appendString(logLine, to: self.workspaceLogUrl)
        }
    }
    
    public func getLogFilePath() -> String {
        return workspaceLogUrl.path
    }
    
    public func clearLogs() {
        queue.async {
            try? "".write(to: self.logFileUrl, atomically: true, encoding: .utf8)
            try? "".write(to: self.workspaceLogUrl, atomically: true, encoding: .utf8)
        }
    }
    
    private func appendString(_ string: String, to url: URL) {
        guard let data = string.data(using: .utf8) else { return }
        if fileManager.fileExists(atPath: url.path) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
