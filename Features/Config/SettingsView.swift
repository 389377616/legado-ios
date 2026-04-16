//
//  SettingsView.swift
//  Legado-iOS
//
//  设置界面
//

import SwiftUI
import CoreData

struct SettingsLegacyView: View {
    @AppStorage("webServer.enabled") private var webServerEnabled = false
    @AppStorage("webServer.port") private var webServerPort = 1122
    @StateObject private var webServerCoordinator = WebServerCoordinator.shared

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("内容")) {
                    NavigationLink("书源管理") {
                        SourceManageView()
                    }

                    NavigationLink("书源订阅") {
                        SourceSubscriptionView()
                    }

                    NavigationLink("数据迁移") {
                        DataMigrationView()
                    }
                }

                Section(header: Text("阅读")) {
                    NavigationLink("阅读设置") {
                        ReaderSettingsFullView()
                    }
                    
                    NavigationLink("主题") {
                        AppThemeSettingsView()
                    }
                }
                
                Section(header: Text("TTS")) {
                    NavigationLink("在线TTS引擎") {
                        HttpTTSConfigView()
                    }
                    
                    NavigationLink("本地朗读设置") {
                        TTSSettingsView()
                    }
                }
                
                Section(header: Text("数据")) {
                    NavigationLink("备份与恢复") {
                        BackupRestoreView()
                    }
                    
                    NavigationLink("清理缓存") {
                        CacheCleanView()
                    }
                    
                    NavigationLink("文件管理") {
                        FileManageView()
                    }
                }

                Section(header: Text("Web 服务")) {
                    Toggle("启用 Web 服务", isOn: $webServerEnabled)

                    Stepper(value: $webServerPort, in: 1024...65535) {
                        Text("端口: \(webServerPort)")
                    }
                    .disabled(!webServerEnabled)

                    HStack {
                        Text("状态")
                        Spacer()
                        Text(webServerCoordinator.isRunning ? "运行中" : "已停止")
                            .foregroundColor(webServerCoordinator.isRunning ? .green : .secondary)
                    }

                    if let lastErrorMessage = webServerCoordinator.lastErrorMessage, !lastErrorMessage.isEmpty {
                        Text(lastErrorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Text("局域网访问: http://<本机IP>:\(webServerPort)/health")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("规则")) {
                    NavigationLink("替换规则") {
                        ReplaceRuleView()
                    }
                    
                    NavigationLink("目录规则") {
                        TxtTocRuleView()
                    }
                    
                    NavigationLink("词典规则") {
                        DictRuleView()
                    }
                }
                
                Section(header: Text("统计")) {
                    NavigationLink("全部书签") {
                        AllBookmarksView()
                    }

                    NavigationLink("阅读统计") {
                        ReadingStatsView()
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
            .onAppear {
                syncWebServerState()
            }
            .onChange(of: webServerEnabled) { _ in
                syncWebServerState()
            }
            .onChange(of: webServerPort) { _ in
                if webServerEnabled {
                    webServerCoordinator.start(port: webServerPort)
                }
            }
        }
    }

    private func syncWebServerState() {
        if webServerEnabled {
            webServerCoordinator.start(port: webServerPort)
        } else {
            webServerCoordinator.stop()
        }
    }
}

struct TTSSettingsView: View {
    @AppStorage("tts.rate") private var rate: Double = 0.5
    @AppStorage("tts.pitch") private var pitch: Double = 1.0
    @AppStorage("tts.volume") private var volume: Double = 1.0
    
    var body: some View {
        Form {
            Section(header: Text("朗读速度")) {
                Slider(value: $rate, in: 0.0...1.0) {
                    Text("速度: \(Int(rate * 100))%")
                }
            }
            
            Section(header: Text("音调")) {
                Slider(value: $pitch, in: 0.5...2.0) {
                    Text("音调: \(String(format: "%.1f", pitch))")
                }
            }
            
            Section(header: Text("音量")) {
                Slider(value: $volume, in: 0.0...1.0) {
                    Text("音量: \(Int(volume * 100))%")
                }
            }
        }
        .navigationTitle("朗读设置")
    }
}

struct ReadingStatsView: View {
    @StateObject private var manager = ReadingStatisticsManager()
    
    var body: some View {
        List {
            Section(header: Text("总计")) {
                HStack {
                    Text("阅读时长")
                    Spacer()
                    Text(formatDuration(manager.statistics.totalReadingTime))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("阅读字数")
                    Spacer()
                    Text("\(manager.statistics.totalWords) 字")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("阅读章节")
                    Spacer()
                    Text("\(manager.statistics.totalChapters) 章")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("阅读书籍")
                    Spacer()
                    Text("\(manager.statistics.totalBooks) 本")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("日均")) {
                HStack {
                    Text("日均时长")
                    Spacer()
                    Text(formatDuration(manager.statistics.averageDailyTime))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("日均字数")
                    Spacer()
                    Text("\(manager.statistics.averageDailyWords) 字")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("阅读统计")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        }
        return "\(minutes)分钟"
    }
}

struct AllBookmarksView: View {
    @State private var bookmarks: [Bookmark] = []

    var body: some View {
        List {
            if bookmarks.isEmpty {
                EmptyStateView(
                    title: "暂无书签",
                    subtitle: "阅读时添加的书签会显示在这里",
                    imageName: "bookmark"
                )
            } else {
                ForEach(bookmarks, id: \.bookmarkId) { bookmark in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(bookmark.book?.name ?? "未知书籍")
                            .font(.headline)
                        Text(bookmark.chapterTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if !bookmark.content.isEmpty {
                            Text(bookmark.content)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .onDelete(perform: deleteBookmarks)
            }
        }
        .navigationTitle("全部书签")
        .task {
            loadBookmarks()
        }
    }

    private func loadBookmarks() {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createDate", ascending: false)]
        bookmarks = (try? context.fetch(request)) ?? []
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        let context = CoreDataStack.shared.viewContext
        for index in offsets {
            context.delete(bookmarks[index])
        }
        do {
            try context.save()
            bookmarks.remove(atOffsets: offsets)
        } catch {
            DebugLogger.shared.log("删除书签失败: \(error)")
        }
    }
}

#Preview {
    SettingsLegacyView()
}
