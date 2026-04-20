import SwiftUI

struct HelpView: View {
    var body: some View {
        List {
            Section {
                helpRow(icon: "book", title: "添加书籍", detail: "通过搜索、导入本地文件或输入URL添加书籍")
                helpRow(icon: "magnifyingglass", title: "搜索书籍", detail: "在发现页面搜索书名，支持多源并发搜索")
                helpRow(icon: "text.page.slash", title: "阅读设置", detail: "阅读时点击屏幕中部呼出菜单，可调整字号、主题、翻页动画")
                helpRow(icon: "arrow.left.arrow.right", title: "替换净化", detail: "在设置中配置替换规则，自动净化广告和干扰内容")
                helpRow(icon: "arrow.clockwise", title: "备份恢复", detail: "通过WebDAV同步书籍和书源数据")
            }
            
            Section {
                helpRow(icon: "network", title: "Web服务", detail: "启动后在电脑浏览器中管理书源和书籍")
                helpRow(icon: "qrcode.viewfinder", title: "扫码导入", detail: "扫描二维码快速导入书源")
            }
            
            Section {
                Link(destination: URL(string: "https://github.com/gedoor/legado")!) {
                    HStack {
                        Image(systemName: "globe")
                            .frame(width: 24)
                            .foregroundColor(.accentColor)
                        Text("开源项目")
                            .font(.system(size: 16))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("帮助")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func helpRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}