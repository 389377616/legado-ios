import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("应用信息")) {
                    HStack {
                        Image("AppIcon")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Legado")
                                .font(.headline)
                            Text("开源阅读应用")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("版本 \(appVersion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("项目信息")) {
                    LinkRow(title: "GitHub 仓库", subtitle: "legado-ios", url: "https://github.com/legado-ios/legado-ios")
                    LinkRow(title: "安卓原版", subtitle: "Legado", url: "https://github.com/Luoyacheng/legado")
                    LinkRow(title: "问题反馈", subtitle: "提交 Issue", url: "https://github.com/legado-ios/legado-ios/issues")
                }
                
                Section(header: Text("开源许可")) {
                    NavigationLink(destination: OpenSourceLicensesView()) {
                        Text("开源组件许可")
                    }
                }
                
                Section(header: Text("功能特性")) {
                    FeatureRow(icon: "books.vertical", title: "书源规则", description: "自定义书源，自由订阅")
                    FeatureRow(icon: "doc.text", title: "本地阅读", description: "支持 TXT、EPUB 格式")
                    FeatureRow(icon: "book.pages", title: "阅读设置", description: "多种翻页模式、字体设置")
                    FeatureRow(icon: "moon", title: "夜间模式", description: "护眼阅读体验")
                    FeatureRow(icon: "speaker.wave.2", title: "朗读功能", description: "TTS 语音朗读")
                    FeatureRow(icon: "cloud", title: "WebDAV 同步", description: "云端备份恢复")
                }
                
                Section(header: Text("致谢")) {
                    Text("感谢安卓 Legado 原版作者的开源贡献")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("感谢所有开源社区的贡献者")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("版权声明")) {
                    Text("本应用基于安卓 Legado 原版移植，遵循 GPL-3.0 许可协议。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct LinkRow: View {
    let title: String
    let subtitle: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.subheadline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct OpenSourceLicensesView: View {
    var body: some View {
        List {
            Section(header: Text("SwiftUI")) {
                Text("Apple Inc. - SwiftUI Framework")
                    .font(.caption)
            }
            
            Section(header: Text("ZIPFoundation")) {
                Text("Thomas Zoechling - ZIPFoundation")
                    .font(.caption)
                Text("MIT License")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("SwiftSoup")) {
                Text("Nabil Chatbi - SwiftSoup")
                    .font(.caption)
                Text("MIT License")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Combine")) {
                Text("Apple Inc. - Combine Framework")
                    .font(.caption)
            }
            
            Section(header: Text("CoreData")) {
                Text("Apple Inc. - CoreData Framework")
                    .font(.caption)
            }
            
            Section(header: Text("WKWebView")) {
                Text("Apple Inc. - WebKit Framework")
                    .font(.caption)
            }
        }
        .navigationTitle("开源许可")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AboutView()
}