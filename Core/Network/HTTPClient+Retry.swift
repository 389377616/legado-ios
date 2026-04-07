//
//  HTTPClient+Retry.swift
//  Legado-iOS
//
//  网络请求重试机制
//

import Foundation

extension HTTPClient {
    
    struct RetryConfig {
        var maxRetries: Int
        var initialDelay: TimeInterval
        var maxDelay: TimeInterval
        var multiplier: Double
        var retryableStatusCodes: Set<Int>
        
        static let `default` = RetryConfig(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504]
        )
        
        static let aggressive = RetryConfig(
            maxRetries: 5,
            initialDelay: 0.5,
            maxDelay: 60.0,
            multiplier: 1.5,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504]
        )
        
        static let none = RetryConfig(
            maxRetries: 0,
            initialDelay: 0,
            maxDelay: 0,
            multiplier: 1.0,
            retryableStatusCodes: []
        )
    }
    
    func getWithRetry(
        url: String,
        headers: [String: String]? = nil,
        timeout: TimeInterval? = nil,
        config: RetryConfig = .default
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        var lastError: Error?
        
        for attempt in 0...config.maxRetries {
            do {
                return try await get(url: url, headers: headers, timeout: timeout)
            } catch {
                lastError = error
                
                if !shouldRetry(error: error, config: config, attempt: attempt) {
                    throw error
                }
                
                let delay = calculateDelay(attempt: attempt, config: config)
                Logger.shared.debug("网络请求重试 \(attempt + 1)/\(config.maxRetries), 等待 \(delay)s: \(url)")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? NetworkError.networkFailure(URLError(.unknown))
    }
    
    func postWithRetry(
        url: String,
        body: Data? = nil,
        headers: [String: String]? = nil,
        config: RetryConfig = .default
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        var lastError: Error?
        
        for attempt in 0...config.maxRetries {
            do {
                return try await post(url: url, body: body, headers: headers)
            } catch {
                lastError = error
                
                if !shouldRetry(error: error, config: config, attempt: attempt) {
                    throw error
                }
                
                let delay = calculateDelay(attempt: attempt, config: config)
                Logger.shared.debug("POST 请求重试 \(attempt + 1)/\(config.maxRetries), 等待 \(delay)s: \(url)")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? NetworkError.networkFailure(URLError(.unknown))
    }
    
    private func shouldRetry(error: Error, config: RetryConfig, attempt: Int) -> Bool {
        guard attempt < config.maxRetries else { return false }
        
        if let networkError = error as? NetworkError {
            switch networkError {
            case .timeout, .noConnection:
                return true
            case .httpError(let statusCode):
                return config.retryableStatusCodes.contains(statusCode)
            case .networkFailure:
                return true
            default:
                return false
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func calculateDelay(attempt: Int, config: RetryConfig) -> TimeInterval {
        let delay = config.initialDelay * pow(config.multiplier, Double(attempt))
        return min(delay, config.maxDelay)
    }
}