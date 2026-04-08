import SwiftUI
import CoreData

struct MyView: View {
    @StateObject private var statistics = ReadingStatisticsManager()
    
    var body: some View {
        List {
            Section("阅读统计") {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                    Text("今日阅读")
                    Spacer()
                    Text(formatDuration(statistics.todayReadingTime))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "books.vertical.fill")
                        .foregroundColor(.green)
                    Text("总计时长")
                    Spacer()
                    Text(formatDuration(statistics.statistics.totalReadingTime))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "character.book.closed.fill")
                        .foregroundColor(.orange)
                    Text("阅读字数")
                    Spacer()
                    Text("\(statistics.statistics.totalWords) 字")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("书架管理") {
                NavigationLink("书源管理") {
                    SourceManageView()
                }
                
                NavigationLink("书源订阅") {
                    SourceSubscriptionView()
                }
                
                NavigationLink("分组管理") {
                    GroupManageView()
                }
            }
            
            Section("内容管理") {
                NavigationLink("替换规则") {
                    ReplaceRuleView()
                }
                
                NavigationLink("词典规则") {
                    DictRuleView()
                }
                
                NavigationLink("TXT目录规则") {
                    TxtTocRuleView()
                }
            }
            
            Section("数据") {
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
            
            Section("朗读") {
                NavigationLink("在线TTS引擎") {
                    HttpTTSConfigView()
                }
                
                NavigationLink("朗读设置") {
                    TTSSettingsView()
                }
            }
            
            Section("Web服务") {
                WebServerSectionView()
            }
            
            Section("关于") {
                NavigationLink("阅读统计") {
                    ReadingStatsView()
                }
                
                NavigationLink("全部书签") {
                    AllBookmarksView()
                }
                
                NavigationLink("关于") {
                    AboutDetailView()
                }
                
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

struct WebServerSectionView: View {
    @AppStorage("webServer.enabled") private var webServerEnabled = false
    @AppStorage("webServer.port") private var webServerPort = 1122
    @StateObject private var coordinator = WebServerCoordinator.shared
    
    var body: some View {
        Toggle("启用 Web 服务", isOn: $webServerEnabled)
        
        Stepper(value: $webServerPort, in: 1024...65535) {
            Text("端口: \(webServerPort)")
        }
        .disabled(!webServerEnabled)
        
        HStack {
            Text("状态")
            Spacer()
            Text(coordinator.isRunning ? "运行中" : "已停止")
                .foregroundColor(coordinator.isRunning ? .green : .secondary)
        }
        
        if let error = coordinator.lastErrorMessage, !error.isEmpty {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
        }
        
        Text("局域网访问: http://<本机IP>:\(webServerPort)/health")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

struct AboutDetailView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Legado iOS")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("版本 1.0.0")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            
            Section("关于") {
                Text("Legado iOS 是基于 Android 开源阅读器的 iOS 原生移植版本，支持自定义书源、本地阅读、RSS订阅等功能。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Section("功能特性") {
                FeatureRow(icon: "books.vertical", text: "自定义书源规则")
                FeatureRow(icon: "magnifyingglass", text: "多书源聚合搜索")
                FeatureRow(icon: "book.fill", text: "多种翻页动画")
                FeatureRow(icon: "speaker.wave.2.fill", text: "在线TTS朗读")
                FeatureRow(icon: "antenna.radiowaves.left.and.right", text: "RSS订阅管理")
                FeatureRow(icon: "doc.text.fill", text: "本地TXT/EPUB支持")
            }
            
            Section("开源协议") {
                Text("本项目基于 GPL-3.0 协议开源")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)
            Text(text)
        }
    }
}