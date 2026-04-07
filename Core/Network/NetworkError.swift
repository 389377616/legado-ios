//
//  NetworkError.swift
//  Legado-iOS
//
//  统一网络错误模型
//

import Foundation

/// 应用统一错误类型
enum AppError: LocalizedError {
    // 网络错误
    case network(NetworkError)
    
    // 数据错误
    case data(DataError)
    
    // 规则错误
    case rule(RuleError)
    
    // 存储 错误
    case storage(StorageError)
    
    // 其他错误
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.errorDescription
        case .data(let error):
            return error.errorDescription
        case .rule(let error):
            return error.errorDescription
        case .storage(let error):
            return error.errorDescription
        case .unknown(let message):
            return message
        }
    }
}

/// 网络错误
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case networkFailure(Error)
    case timeout
    case noConnection
    case sslError
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let statusCode):
            return "HTTP 错误：\(statusCode)"
        case .networkFailure(let error):
            return "网络错误：\(error.localizedDescription)"
        case .timeout:
            return "请求超时"
        case .noConnection:
            return "网络连接不可用"
        case .sslError:
            return "SSL 证书错误"
        case .cancelled:
            return "请求已取消"
        }
    }
    
    /// 是否可重试
    var isRetryable: Bool {
        switch self {
        case .timeout, .networkFailure, .noConnection:
            return true
        default:
            return false
        }
    }
}

/// 数据错误
enum DataError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case invalidFormat
    case missingData
    case corruptedData
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "数据编码失败"
        case .decodingFailed:
            return "数据解码失败"
        case .invalidFormat:
            return "数据格式无效"
        case .missingData:
            return "缺少必要数据"
        case .corruptedData:
            return "数据已损坏"
        }
    }
}

/// 规则错误
enum RuleError: LocalizedError {
    case ruleNotFound
    case ruleExecutionFailed(String)
    case invalidRuleSyntax(String)
    case jsExecutionError(String)
    case htmlParseError(String)
    case xpathError(String)
    case regexError(String)
    
    var errorDescription: String? {
        switch self {
        case .ruleNotFound:
            return "规则未找到"
        case .ruleExecutionFailed(let detail):
            return "规则执行失败：\(detail)"
        case .invalidRuleSyntax(let detail):
            return "规则语法错误：\(detail)"
        case .jsExecutionError(let detail):
            return "JS 执行错误：\(detail)"
        case .htmlParseError(let detail):
            return "HTML 解析错误：\(detail)"
        case .xpathError(let detail):
            return "XPath 错误：\(detail)"
        case .regexError(let detail):
            return "正则表达式错误：\(detail)"
        }
    }
}

/// 存储错误
enum StorageError: LocalizedError {
    case saveFailed
    case readFailed
    case deleteFailed
    case fileNotFound
    case insufficientSpace
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "保存失败"
        case .readFailed:
            return "读取失败"
        case .deleteFailed:
            return "删除失败"
        case .fileNotFound:
            return "文件未找到"
        case .insufficientSpace:
            return "存储空间不足"
        case .permissionDenied:
            return "权限被拒绝"
        }
    }
}

// MARK: - Error Extension

extension Error {
    /// 转换为 AppError
    var toAppError: AppError {
        if let appError = self as? AppError {
            return appError
        }
        
        if let networkError = self as? NetworkError {
            return .network(networkError)
        }
        
        if let urlError = self as? URLError {
            switch urlError.code {
            case .timedOut:
                return .network(.timeout)
            case .notConnectedToInternet:
                return .network(.noConnection)
            case .cancelled:
                return .network(.cancelled)
            case .serverCertificateUntrusted, .serverCertificateHasBadRootAuthority:
                return .network(.sslError)
            default:
                return .network(.networkFailure(self))
            }
        }
        
        return .unknown(self.localizedDescription)
    }
}