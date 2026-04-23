//
//  DownloadService.swift
//  Legado-iOS
//
//  文件下载服务 - 1:1 对齐 Android DownloadService.kt
//

import Foundation
import Combine

/// 下载信息（对应 Android DownloadInfo）
struct DownloadInfo: Identifiable {
    let id: UUID
    let url: String
    let fileName: String
    var progress: Double = 0
    var downloadedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var status: Status = .pending
    let startTime: Date
    
    enum Status: String {
        case pending = "等待下载"
        case downloading = "下载中"
        case paused = "已暂停"
        case completed = "下载完成"
        case failed = "下载出错"
    }
    
    init(url: String, fileName: String) {
        self.id = UUID()
        self.url = url
        self.fileName = fileName
        self.startTime = Date()
    }
}

/// 文件下载服务 - 对应 Android DownloadService
@MainActor
class DownloadService: ObservableObject {
    
    static let shared = DownloadService()
    
    @Published var downloads: [UUID: DownloadInfo] = [:]
    @Published var isRunning: Bool = false
    
    private var urlSession: URLSession!
    private var tasks: [UUID: URLSessionDownloadTask] = [:]
    private var completionHandlers: [UUID: (URL?) -> Void] = [:]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }
    
    // MARK: - 公开方法（对应 Android onStartCommand）
    
    /// 开始下载（对应 Android startDownload）
    func startDownload(url: String, fileName: String, completion: ((URL?) -> Void)? = nil) {
        guard !url.isEmpty, !fileName.isEmpty else {
            if downloads.isEmpty {
                isRunning = false
            }
            return
        }
        
        // 检查是否已在下载列表
        if downloads.values.contains(where: { $0.url == url }) {
            return
        }
        
        var info = DownloadInfo(url: url, fileName: fileName)
        let id = info.id
        downloads[id] = info
        isRunning = true
        
        if let completion = completion {
            completionHandlers[id] = completion
        }
        
        guard let requestUrl = URL(string: url) else {
            downloads[id]?.status = .failed
            return
        }
        
        let task = urlSession.downloadTask(with: requestUrl) { [weak self] tempUrl, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.downloads[id]?.status = .failed
                    self.tasks.removeValue(forKey: id)
                    return
                }
                
                guard let tempUrl = tempUrl else {
                    self.downloads[id]?.status = .failed
                    self.tasks.removeValue(forKey: id)
                    return
                }
                
                // 保存到 Documents/Downloads 目录
                let destDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("Downloads")
                
                do {
                    try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                    let destUrl = destDir.appendingPathComponent(fileName)
                    
                    // 如果目标文件已存在，先删除
                    if FileManager.default.fileExists(atPath: destUrl.path) {
                        try FileManager.default.removeItem(at: destUrl)
                    }
                    
                    try FileManager.default.moveItem(at: tempUrl, to: destUrl)
                    
                    self.downloads[id]?.status = .completed
                    self.downloads[id]?.progress = 1.0
                    
                    if let totalBytes = response?.expectedContentLength {
                        self.downloads[id]?.totalBytes = totalBytes
                        self.downloads[id]?.downloadedBytes = totalBytes
                    }
                    
                    self.completionHandlers[id]?(destUrl)
                    self.completionHandlers.removeValue(forKey: id)
                } catch {
                    self.downloads[id]?.status = .failed
                }
                
                self.tasks.removeValue(forKey: id)
                self.checkServiceState()
            }
        }
        
        // 监控进度
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.downloads[id]?.progress = progress.fractionCompleted
                self?.downloads[id]?.status = .downloading
            }
        }
        
        tasks[id] = task
        task.resume()
    }
    
    /// 取消下载（对应 Android removeDownload）
    func removeDownload(id: UUID) {
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)
        downloads.removeValue(forKey: id)
        completionHandlers.removeValue(forKey: id)
        checkServiceState()
    }
    
    /// 暂停下载
    func pauseDownload(id: UUID) {
        tasks[id]?.suspend()
        downloads[id]?.status = .paused
    }
    
    /// 恢复下载
    func resumeDownload(id: UUID) {
        tasks[id]?.resume()
        downloads[id]?.status = .downloading
    }
    
    /// 取消所有下载
    func cancelAll() {
        for (id, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
        downloads.removeAll()
        completionHandlers.removeAll()
        isRunning = false
    }
    
    // MARK: - 私有方法
    
    private func checkServiceState() {
        let hasActiveDownloads = downloads.values.contains(where: { 
            $0.status == .downloading || $0.status == .pending 
        })
        isRunning = hasActiveDownloads
        
        if downloads.isEmpty {
            isRunning = false
        }
    }
    
    /// 获取下载文件路径（对应 Android openDownload）
    func getDownloadedFilePath(fileName: String) -> URL? {
        let destDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Downloads")
        let fileUrl = destDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileUrl.path) ? fileUrl : nil
    }
}