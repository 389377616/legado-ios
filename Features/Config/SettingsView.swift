//
//  SettingsView.swift
//  Legado-iOS
//
//  设置界面
//

import SwiftUI
import CoreData

struct SettingsLegacyView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("阅读")) {
                    NavigationLink("阅读设置") {
                        Text("阅读设置")
                    }
                    
                    NavigationLink("主题") {
                        Text("主题")
                    }
                }
                
                Section(header: Text("数据")) {
                    NavigationLink("备份与恢复") {
                        BackupRestoreView()
                    }
                    
                    NavigationLink("清理缓存") {
                        CacheCleanView()
                    }
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("开源地址", destination: URL(string: "https://github.com/gedoor/legado")!)
                    
                    Link("帮助文档", destination: URL(string: "https://www.legado.top/")!)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
        }
    }
}

struct CacheCleanView: View {
    @State private var logSize: Int64 = 0
    @State private var chapterSize: Int64 = 0
    @State private var coverSize: Int64 = 0
    @State private var isCleaning = false
    @State private var showSuccess = false
    
    private var totalSize: Int64 { logSize + chapterSize + coverSize }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("日志文件")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: logSize, countStyle: .file))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("章节缓存")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: chapterSize, countStyle: .file))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("封面缓存")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: coverSize, countStyle: .file))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("总计")
                        .fontWeight(.medium)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("缓存占用")
            }
            
            Section {
                Button(role: .destructive) {
                    cleanAllCache()
                } label: {
                    HStack {
                        Spacer()
                        if isCleaning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("清理全部缓存")
                        }
                        Spacer()
                    }
                }
                .disabled(isCleaning || totalSize == 0)
            }
        }
        .navigationTitle("清理缓存")
        .onAppear { calculateCacheSize() }
        .alert("清理完成", isPresented: $showSuccess) {
            Button("确定", role: .cancel) { }
        }
    }
    
    private func calculateCacheSize() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        
        let logURL = documents.appendingPathComponent("debug.log")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
           let size = attrs[.size] as? Int64 {
            logSize = size
        }
        
        let chapterDir = documents.appendingPathComponent("chapters")
        chapterSize = directorySize(at: chapterDir)
        
        let coverDir = supportDir.appendingPathComponent("covers")
        coverSize = directorySize(at: coverDir)
    }
    
    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
    
    private func cleanAllCache() {
        isCleaning = true
        
        Task { @MainActor in
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            
            let logURL = documents.appendingPathComponent("debug.log")
            try? "".write(to: logURL, atomically: true, encoding: .utf8)
            
            let chapterDir = documents.appendingPathComponent("chapters")
            try? FileManager.default.removeItem(at: chapterDir)
            
            let coverDir = supportDir.appendingPathComponent("covers")
            try? FileManager.default.removeItem(at: coverDir)
            
            logSize = 0
            chapterSize = 0
            coverSize = 0
            
            isCleaning = false
            showSuccess = true
        }
    }
}

#Preview {
    SettingsLegacyView()
}