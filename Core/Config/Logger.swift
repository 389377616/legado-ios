//
//  Logger.swift
//  Legado-iOS
//
//  日志系统 - 分级日志 + 文件输出
//

import Foundation
import os.log

/// 日志级别
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    var prefix: String {
        switch self {
        case .debug: return "🔍 DEBUG"
        case .info: return "ℹ️ INFO"
        case .warning: return "⚠️ WARN"
        case .error: return "❌ ERROR"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// 日志管理器
final class Logger {
    static let shared = Logger()
    
    var minimumLevel: LogLevel = {
        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }()
    
    var enableFileLogging: Bool = true
    var enableConsoleLogging: Bool = true
    
    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let currentLogFile: URL
    private let queue = DispatchQueue(label: "com.legado.logger", qos: .utility)
    private let osLog = OSLog(subsystem: "com.legado.app", category: "General")
    
    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        logDirectory = docs.appendingPathComponent("Logs")
        currentLogFile = logDirectory.appendingPathComponent("app.log")
        
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - 日志方法
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
    
    func error(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, error.localizedDescription, file: file, function: function, line: line)
    }
    
    // MARK: - 核心方法
    
    private func log(_ level: LogLevel, _ message: String, file: String, function: String, line: Int) {
        guard level >= minimumLevel else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"
        let fullMessage = "\(level.prefix) \(formattedMessage)"
        
        if enableConsoleLogging {
            os_log("%{public}@", log: osLog, type: level.osLogType, fullMessage)
        }
        
        if enableFileLogging {
            writeToFile(level: level, message: fullMessage)
        }
    }
    
    private func writeToFile(level: LogLevel, message: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(message)\n"
            
            guard let data = line.data(using: .utf8) else { return }
            
            if let handle = try? FileHandle(forWritingTo: self.currentLogFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: self.currentLogFile)
            }
            
            self.checkLogSize()
        }
    }
    
    private func checkLogSize() {
        guard let attributes = try? fileManager.attributesOfItem(atPath: currentLogFile.path),
              let fileSize = attributes[.size] as? Int64,
              fileSize > 5 * 1024 * 1024 else { return }
        
        rotateLog()
    }
    
    private func rotateLog() {
        let timestamp = DateFormatter(fileNameFormat: "yyyy-MM-dd-HHmmss").string(from: Date())
        let archivedLog = logDirectory.appendingPathComponent("app-\(timestamp).log")
        
        try? fileManager.moveItem(at: currentLogFile, to: archivedLog)
        
        cleanOldLogs()
    }
    
    private func cleanOldLogs() {
        guard let logs = try? fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else { return }
        
        let sortedLogs = logs.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 > date2
        }
        
        for (index, log) in sortedLogs.enumerated() where index >= 5 {
            try? fileManager.removeItem(at: log)
        }
    }
    
    // MARK: - 导出日志
    
    func exportLogs() -> URL? {
        let tempDir = fileManager.temporaryDirectory
        let exportPath = tempDir.appendingPathComponent("logs-export.zip")
        
        try? fileManager.removeItem(at: exportPath)
        
        return currentLogFile
    }
    
    func clearLogs() {
        try? fileManager.removeItem(at: currentLogFile)
        try? fileManager.removeItem(at: logDirectory)
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }
}

extension DateFormatter {
    convenience init(fileNameFormat: String) {
        self.init()
        self.dateFormat = fileNameFormat
        self.locale = Locale(identifier: "en_US_POSIX")
    }
}

// MARK: - 便捷方法

func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, file: file, function: function, line: line)
}