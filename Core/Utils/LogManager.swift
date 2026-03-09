//
//  LogManager.swift
//  Legado-iOS
//
//  日志管理器 - 用于应用内查看日志
//

import Foundation
import SwiftUI

@MainActor
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    private let maxLogs = 500
    private let fileManager = FileManager.default
    private let logFileName = "app_logs.txt"
    
    struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
        let file: String
        let line: Int
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
        
        var shortFile: String {
            file.components(separatedBy: "/").last ?? file
        }
    }
    
    enum LogLevel: String, CaseIterable, Equatable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
        
        var color: Color {
            switch self {
            case .debug: return .gray
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .debug: return "💬"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
    
    private init() {
        loadLogsFromFile()
    }
    
    func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        line: Int = #line
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            file: file,
            line: line
        )
        
        logs.append(entry)
        
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        
        appendToFile(entry)
        
        // 同时输出到控制台
        print("[\(level.rawValue)] \(message)")
    }
    
    func debug(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: .debug, file: file, line: line)
    }
    
    func info(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: .info, file: file, line: line)
    }
    
    func warning(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: .warning, file: file, line: line)
    }
    
    func error(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: .error, file: file, line: line)
    }
    
    func clear() {
        logs.removeAll()
        deleteLogFile()
    }
    
    func export() -> String {
        var text = "=== Legado-iOS 日志导出 ===\n"
        text += "导出时间: \(Date())\n"
        text += "日志条数: \(logs.count)\n"
        text += "========================\n\n"
        
        for entry in logs {
            text += "[\(entry.formattedTime)] [\(entry.level.rawValue)] \(entry.shortFile):\(entry.line)\n"
            text += "    \(entry.message)\n\n"
        }
        
        return text
    }
    
    private var logFileURL: URL? {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent(logFileName)
    }
    
    private func appendToFile(_ entry: LogEntry) {
        guard let fileURL = logFileURL else { return }
        
        let logLine = "[\(entry.formattedTime)] [\(entry.level.rawValue)] \(entry.shortFile):\(entry.line) - \(entry.message)\n"
        
        if let data = logLine.data(using: .utf8) {
            if fileManager.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
    
    private func loadLogsFromFile() {
        guard let fileURL = logFileURL,
              fileManager.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return
        }
        
        // 文件只用于持久化，不加载到内存
        // 内存中的 logs 从空开始，新日志会同时写入文件
    }
    
    private func deleteLogFile() {
        guard let fileURL = logFileURL else { return }
        try? fileManager.removeItem(at: fileURL)
    }
}

// MARK: - 便捷的日志宏
func LogDebug(_ message: String, file: String = #file, line: Int = #line) {
    LogManager.shared.debug(message, file: file, line: line)
}

func LogInfo(_ message: String, file: String = #file, line: Int = #line) {
    LogManager.shared.info(message, file: file, line: line)
}

func LogWarning(_ message: String, file: String = #file, line: Int = #line) {
    LogManager.shared.warning(message, file: file, line: line)
}

func LogError(_ message: String, file: String = #file, line: Int = #line) {
    LogManager.shared.error(message, file: file, line: line)
}
