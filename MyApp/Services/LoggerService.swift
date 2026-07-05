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

    /// Maximum log file size before rotation (1 MB)
    private let maxLogFileSizeBytes: Int = 1_048_576

    public init() {}
    
    public func log(_ message: String, level: LogLevel = .info) {
        queue.async {
            let timestamp = Self.dateFormatter.string(from: Date())
            let logLine = "[\(timestamp)] [\(level.rawValue)] \(message)\n"

            // Print to stdout (debug only)
            #if DEBUG
            print(logLine, terminator: "")
            #endif

            // Rotate log if over size limit before appending
            self.rotateLogIfNeeded()

            // Append to primary log file in Documents
            self.appendString(logLine, to: self.logFileUrl)
        }
    }
    
    public func getLogFilePath() -> String {
        return logFileUrl.path
    }

    public func clearLogs() {
        queue.async {
            try? "".write(to: self.logFileUrl, atomically: true, encoding: .utf8)
        }
    }

    private func rotateLogIfNeeded() {
        guard fileManager.fileExists(atPath: logFileUrl.path),
              let attrs = try? fileManager.attributesOfItem(atPath: logFileUrl.path),
              let size = attrs[.size] as? Int,
              size >= maxLogFileSizeBytes else { return }
        // Truncate to empty — simple rotation strategy
        try? "".write(to: logFileUrl, atomically: true, encoding: .utf8)
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
