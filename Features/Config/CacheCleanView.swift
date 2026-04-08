import SwiftUI
import CoreData

struct CacheCleanView: View {
    @State private var imageCacheSize: String = "计算中..."
    @State private var chapterCacheSize: String = "计算中..."
    @State private var epubCacheSize: String = "计算中..."
    @State private var rssCacheSize: String = "计算中..."
    @State private var logSize: String = "计算中..."
    @State private var isClearing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        List {
            Section("缓存占用") {
                CacheSizeRow(title: "图片缓存", iconName: "photo", size: imageCacheSize)
                CacheSizeRow(title: "章节缓存", iconName: "doc.text", size: chapterCacheSize)
                CacheSizeRow(title: "EPUB缓存", iconName: "book", size: epubCacheSize)
                CacheSizeRow(title: "RSS缓存", iconName: "antenna.radiowaves.left.and.right", size: rssCacheSize)
                CacheSizeRow(title: "日志文件", iconName: "doc.text.fill", size: logSize)
            }
            
            Section {
                Button(action: clearImageCache) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清理图片缓存")
                    }
                }
                
                Button(action: clearChapterCache) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清理章节缓存")
                    }
                }
                
                Button(action: clearEPUBCache) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清理EPUB缓存")
                    }
                }
                
                Button(action: clearRSSCache) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清理RSS缓存")
                    }
                }
                
                Button(action: clearLog) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清理日志")
                    }
                }
                
                Button(role: .destructive, action: clearAll) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("清理全部缓存")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("清理缓存")
        .navigationBarTitleDisplayMode(.inline)
        .task { calculateCacheSize() }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func calculateCacheSize() {
        imageCacheSize = folderSize(imageCacheDir())
        chapterCacheSize = folderSize(chapterCacheDir())
        epubCacheSize = folderSize(epubCacheDir())
        rssCacheSize = folderSize(rssCacheDir())
        logSize = fileSize(logFile())
    }
    
    private func imageCacheDir() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("images", isDirectory: true)
    }
    
    private func chapterCacheDir() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("book_cache", isDirectory: true)
    }
    
    private func epubCacheDir() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("epub_cache", isDirectory: true)
    }
    
    private func rssCacheDir() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("rss_cache", isDirectory: true)
    }
    
    private func logFile() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("debug.log")
    }
    
    private func fileSize(_ url: URL?) -> String {
        guard let url = url else { return "0 B" }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private func folderSize(_ url: URL?) -> String {
        guard let url = url else { return "0 B" }
        let fm = FileManager.default
        var total: Int64 = 0
        
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) else {
            return "0 B"
        }
        
        for case let itemURL as URL in enumerator {
            guard let values = try? itemURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else { continue }
            guard values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    private func clearLog(showMessage: Bool = true) {
        if let url = logFile() {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
        calculateCacheSize()
        if showMessage {
            alertMessage = "日志已清理"
            showingAlert = true
        }
    }
    
    private func clearImageCache(showMessage: Bool = true) {
        clearDir(imageCacheDir())
        ImageCacheManager.shared.clearCache()
        calculateCacheSize()
        if showMessage {
            alertMessage = "图片缓存已清理"
            showingAlert = true
        }
    }
    
    private func clearChapterCache(showMessage: Bool = true) {
        clearDir(chapterCacheDir())
        calculateCacheSize()
        if showMessage {
            alertMessage = "章节缓存已清理"
            showingAlert = true
        }
    }
    
    private func clearEPUBCache(showMessage: Bool = true) {
        clearDir(epubCacheDir())
        calculateCacheSize()
        if showMessage {
            alertMessage = "EPUB缓存已清理"
            showingAlert = true
        }
    }
    
    private func clearRSSCache(showMessage: Bool = true) {
        clearDir(rssCacheDir())
        calculateCacheSize()
        if showMessage {
            alertMessage = "RSS缓存已清理"
            showingAlert = true
        }
    }
    
    private func clearAll() {
        isClearing = true
        defer { isClearing = false }
        
        clearLog(showMessage: false)
        clearImageCache(showMessage: false)
        clearChapterCache(showMessage: false)
        clearEPUBCache(showMessage: false)
        clearRSSCache(showMessage: false)
        alertMessage = "全部缓存已清理"
        showingAlert = true
    }
    
    private func clearDir(_ url: URL?) {
        guard let url = url else { return }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

struct CacheSizeRow: View {
    let title: String
    let iconName: String
    let size: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: iconName)
            Spacer()
            Text(size)
                .foregroundColor(.secondary)
        }
    }
}