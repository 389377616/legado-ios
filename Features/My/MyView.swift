import SwiftUI
import CoreData

struct MyView: View {
    var body: some View {
        List {
            // 书源管理区
            Section {
                PreferenceItem(icon: "doc.text.magnifyingglass", title: "书源管理", summary: "管理书籍来源") {
                    SourceManageView()
                }
                
                PreferenceItem(icon: "list.bullet.indent", title: "TXT目录规则", summary: "TXT文件目录识别规则") {
                    TxtTocRuleView()
                }
                
                PreferenceItem(icon: "arrow.left.arrow.right", title: "替换净化", summary: "内容替换规则") {
                    ReplaceRuleView()
                }
                
                PreferenceItem(icon: "character.book.closed", title: "词典规则", summary: "词典管理") {
                    DictRuleView()
                }
            }
            
            // 外观区
            Section {
                PreferenceItem(icon: "paintbrush", title: "主题模式", summary: "切换应用主题") {
                    AppThemeSettingsView()
                }
            }
            
            // 服务区
            Section {
                WebServicePreferenceItem()
            }
            
            // 数据区
            Section {
                PreferenceItem(icon: "arrow.clockwise", title: "备份与恢复", summary: "WebDAV备份设置") {
                    BackupRestoreView()
                }
                
                PreferenceItem(icon: "gearshape", title: "其他设置", summary: "应用其他配置") {
                    AppConfigView()
                }
            }
            
            // 其他区
            Section {
                PreferenceItem(icon: "bookmark", title: "书签", summary: "所有书签") {
                    AllBookmarksView()
                }
                
                PreferenceItem(icon: "clock", title: "阅读记录", summary: "阅读历史记录") {
                    ReadingStatisticsView()
                }
                
                PreferenceItem(icon: "chart.bar", title: "阅读统计", summary: "阅读数据统计") {
                    ReadingStatisticsView()
                }
                
                PreferenceItem(icon: "doc.text", title: "日志", summary: "应用日志") {
                    DebugLogView()
                }
                
                PreferenceItem(icon: "questionmark.circle", title: "帮助", summary: "使用帮助") {
                    HelpView()
                }
                
                PreferenceItem(icon: "info.circle", title: "关于", summary: "版本信息") {
                    AboutView()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("我的")
    }
}

struct PreferenceItem<Destination: View>: View {
    let icon: String
    let title: String
    let summary: String
    @ViewBuilder let destination: () -> Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

struct PreferenceCategory<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.top, 8)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            content()
            
            Divider()
                .padding(.bottom, 8)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .background(Color(.systemGroupedBackground))
    }
}

struct WebServicePreferenceItem: View {
    @State private var isEnabled = false
    @State private var hostAddress = ""
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Web服务")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                Text(isEnabled ? hostAddress : "在电脑上管理书源和书籍")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

struct AboutPreferenceItem: View {
    var body: some View {
        NavigationLink(destination: Text("关于页面")) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("关于")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Text("版本信息")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    if hours > 0 {
        return "\(hours)小时\(minutes)分钟"
    } else {
        return "\(minutes)分钟"
    }
}
