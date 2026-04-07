//
//  ResponseCache.swift
//  Legado-iOS
//
//  HTTP 响应缓存 - 内存 + 磁盘
//

import Foundation

final class ResponseCache {
    static let shared = ResponseCache()
    
    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let diskCacheURL: URL
    private let queue = DispatchQueue(label: "com.legado.responsecache")
    
    private struct CacheEntry {
        let data: Data
        let response: HTTPURLResponse
        let timestamp: Date
        let ttl: TimeInterval
    }
    
    var memoryCacheLimit: Int = 50 * 1024 * 1024
    var diskCacheLimit: Int = 200 * 1024 * 1024
    var defaultTTL: TimeInterval = 3600
    
    private init() {
        memoryCache.totalCostLimit = memoryCacheLimit
        
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("HTTPCache")
        
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        cleanExpiredCache()
    }
    
    // MARK: - 存储
    
    func store(response: HTTPURLResponse, data: Data, for url: String, ttl: TimeInterval? = nil) {
        let entry = CacheEntry(
            data: data,
            response: response,
            timestamp: Date(),
            ttl: ttl ?? defaultTTL
        )
        
        let key = url as NSString
        memoryCache.setObject(entry, forKey: key, cost: data.count)
        
        queue.async { [weak self] in
            self?.storeToDisk(entry: entry, key: url)
        }
    }
    
    private func storeToDisk(entry: CacheEntry, key: String) {
        let fileURL = diskCacheURL.appendingPathComponent(key.md5)
        
        let metadata: [String: Any] = [
            "timestamp": entry.timestamp.timeIntervalSince1970,
            "ttl": entry.ttl,
            "statusCode": entry.response.statusCode
        ]
        
        var combinedData = Data()
        combinedData.append(try? JSONSerialization.data(withJSONObject: metadata) ?? Data())
        combinedData.append(Data([0x00]))
        combinedData.append(entry.data)
        
        try? combinedData.write(to: fileURL)
    }
    
    // MARK: - 读取
    
    func get(for url: String) -> (data: Data, response: HTTPURLResponse)? {
        let key = url as NSString
        
        if let entry = memoryCache.object(forKey: key) {
            if !isExpired(entry: entry) {
                return (entry.data, entry.response)
            } else {
                memoryCache.removeObject(forKey: key)
            }
        }
        
        if let diskEntry = loadFromDisk(key: url) {
            if !isExpired(entry: diskEntry) {
                memoryCache.setObject(diskEntry, forKey: key, cost: diskEntry.data.count)
                return (diskEntry.data, diskEntry.response)
            }
        }
        
        return nil
    }
    
    private func loadFromDisk(key: String) -> CacheEntry? {
        let fileURL = diskCacheURL.appendingPathComponent(key.md5)
        
        guard let combinedData = try? Data(contentsOf: fileURL),
              let separatorIndex = combinedData.firstIndex(of: 0x00) else {
            return nil
        }
        
        let metadataData = combinedData[..<separatorIndex]
        let data = combinedData[combinedData.index(after: separatorIndex)...]
        
        guard let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
              let timestamp = metadata["timestamp"] as? TimeInterval,
              let ttl = metadata["ttl"] as? TimeInterval,
              let statusCode = metadata["statusCode"] as? Int,
              let response = HTTPURLResponse(
                url: URL(string: key) ?? URL(fileURLWithPath: ""),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
              ) else {
            return nil
        }
        
        return CacheEntry(
            data: Data(data),
            response: response,
            timestamp: Date(timeIntervalSince1970: timestamp),
            ttl: ttl
        )
    }
    
    // MARK: - 清理
    
    func remove(for url: String) {
        let key = url as NSString
        memoryCache.removeObject(forKey: key)
        
        queue.async { [weak self] in
            let fileURL = self?.diskCacheURL.appendingPathComponent(url.md5)
            if let fileURL = fileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    func clearAll() {
        memoryCache.removeAllObjects()
        
        queue.async { [weak self] in
            guard let self = self else { return }
            if let files = try? FileManager.default.contentsOfDirectory(at: self.diskCacheURL, includingPropertiesForKeys: nil) {
                files.forEach { try? FileManager.default.removeItem(at: $0) }
            }
        }
    }
    
    private func isExpired(entry: CacheEntry) -> Bool {
        let elapsed = Date().timeIntervalSince(entry.timestamp)
        return elapsed > entry.ttl
    }
    
    private func cleanExpiredCache() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: self.diskCacheURL,
                includingPropertiesForKeys: nil
            ) else { return }
            
            for fileURL in files {
                guard let combinedData = try? Data(contentsOf: fileURL),
                      let separatorIndex = combinedData.firstIndex(of: 0x00) else { continue }
                
                let metadataData = combinedData[..<separatorIndex]
                
                guard let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                      let timestamp = metadata["timestamp"] as? TimeInterval,
                      let ttl = metadata["ttl"] as? TimeInterval else { continue }
                
                let entryDate = Date(timeIntervalSince1970: timestamp)
                let elapsed = Date().timeIntervalSince(entryDate)
                
                if elapsed > ttl {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }
}

// MARK: - HTTPClient Extension

extension HTTPClient {
    func getWithCache(
        url: String,
        headers: [String: String]? = nil,
        ttl: TimeInterval? = nil,
        forceRefresh: Bool = false
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        if !forceRefresh, let cached = ResponseCache.shared.get(for: url) {
            return cached
        }
        
        let result = try await get(url: url, headers: headers)
        
        if result.response.statusCode == 200 {
            ResponseCache.shared.store(response: result.response, data: result.data, for: url, ttl: ttl)
        }
        
        return result
    }
}

// MARK: - String MD5

import CryptoKit

private extension String {
    var md5: String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}