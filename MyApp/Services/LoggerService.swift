import Foundation
import os

public enum LogLevel: String, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case fault = "FAULT"
    case success = "SUCCESS"
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info, .success: return .info
        case .warning: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .fault: return "💥"
        case .success: return "✅"
        }
    }
}

public enum LogCategory: String, Sendable {
    case general = "General"
    case codeRunner = "CodeRunner"
    case database = "Database"
    case ui = "UI"
    case network = "Network"
    case crash = "Crash"
}

public protocol LoggerServiceProtocol {
    func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int)
    func getLogFilePath() -> String
    func readLogs() -> String
    func clearLogs()
}

public class LoggerService: LoggerServiceProtocol, @unchecked Sendable {
    public static let shared = LoggerService()
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.swiftforge.logger", qos: .utility)
    
    private let osLoggers: [LogCategory: os.Logger] = [
        .general: os.Logger(subsystem: "com.sachinkumar.SwiftForge", category: "General"),
        .codeRunner: os.Logger(subsystem: "com.sachinkumar.SwiftForge", category: "CodeRunner"),
        .database: os.Logger(subsystem: "com.sachinkumar.SwiftForge", category: "Database"),
        .ui: os.Logger(subsystem: "com.sachinkumar.SwiftForge", category: "UI"),
        .network: os.Logger(subsystem: "com.sachinkumar.SwiftForge", category: "Network"),
        .crash: os.Logger(subsystem: "com.sachinkumar.SwiftForge", category: "Crash")
    ]
    
    public var logFileUrl: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("swiftforge_execution.log")
    }

    public var backupLogFileUrl: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("swiftforge_execution.log.1")
    }

    /// Maximum log file size before rotation (1 MB)
    private let maxLogFileSizeBytes: Int = 1_048_576

    public init() {
        setupCrashHandlers()
    }
    
    public func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = Self.dateFormatter.string(from: Date())
        let formattedLog = "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] [\(fileName):\(line) \(function)] \(level.emoji) \(message)\n"

        // 1. Unified OSLog Stream (Mac Console.app & Xcode Console)
        if let osLogger = osLoggers[category] {
            osLogger.log(level: level.osLogType, "[\(category.rawValue)] [\(fileName):\(line)] \(message)")
        }

        // 2. Stdout print for debugging
        #if DEBUG
        print(formattedLog, terminator: "")
        #endif

        // 3. Persistent File Logging with Auto-Rotation
        queue.async {
            self.rotateLogIfNeeded()
            self.appendString(formattedLog, to: self.logFileUrl)
        }
    }
    
    public func getLogFilePath() -> String {
        return logFileUrl.path
    }

    public func readLogs() -> String {
        var result = ""
        queue.sync {
            let primary = (try? String(contentsOf: self.logFileUrl, encoding: .utf8)) ?? ""
            let backup = (try? String(contentsOf: self.backupLogFileUrl, encoding: .utf8)) ?? ""
            result = backup.isEmpty ? primary : (backup + "\n--- Log Rotated ---\n" + primary)
        }
        return result
    }

    public func clearLogs() {
        queue.async {
            try? "".write(to: self.logFileUrl, atomically: true, encoding: .utf8)
            try? "".write(to: self.backupLogFileUrl, atomically: true, encoding: .utf8)
        }
    }

    private func rotateLogIfNeeded() {
        guard fileManager.fileExists(atPath: logFileUrl.path),
              let attrs = try? fileManager.attributesOfItem(atPath: logFileUrl.path),
              let size = attrs[.size] as? Int,
              size >= maxLogFileSizeBytes else { return }
        
        try? fileManager.removeItem(at: backupLogFileUrl)
        try? fileManager.moveItem(at: logFileUrl, to: backupLogFileUrl)
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

    private func setupCrashHandlers() {
        NSSetUncaughtExceptionHandler { exception in
            let crashLog = """
            💥 UNCAUGHT EXCEPTION CRASH DETECTED 💥
            Name: \(exception.name.rawValue)
            Reason: \(exception.reason ?? "Unknown")
            Call Stack:
            \(exception.callStackSymbols.joined(separator: "\n"))
            """
            LoggerService.shared.log(crashLog, level: .fault, category: .crash)
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
