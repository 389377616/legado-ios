import SwiftUI
import CoreData

struct RssSourceDebugView: View {
    let source: RssSource
    @Environment(\.dismiss) private var dismiss
    
    @State private var testUrl: String = ""
    @State private var debugLog: [String] = []
    @State private var isRunning = false
    @State private var articles: [RSSArticle] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section("测试URL") {
                        TextField("输入测试URL（可选）", text: $testUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    Section("操作") {
                        Button(action: runDebug) {
                            HStack {
                                if isRunning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text("运行调试")
                            }
                        }
                        .disabled(isRunning)
                    }
                    
                    if !articles.isEmpty {
                        Section("解析结果 (\(articles.count) 条)") {
                            ForEach(articles.prefix(10)) { article in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(article.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text(article.link)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    
                    if !debugLog.isEmpty {
                        Section("调试日志") {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(debugLog.indices, id: \.self) { index in
                                        Text(debugLog[index])
                                            .font(.system(.caption2, design: .monospaced))
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                }
            }
            .navigationTitle("RSS源调试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清空") {
                        debugLog = []
                        articles = []
                    }
                }
            }
        }
    }
    
    private func runDebug() {
        guard !isRunning else { return }
        
        isRunning = true
        debugLog = []
        articles = []
        
        let url = testUrl.isEmpty ? source.sourceUrl : testUrl
        
        addLog("开始调试: \(url)")
        addLog("源名称: \(source.sourceName)")
        addLog("源地址: \(source.sourceUrl)")
        
        Task {
            do {
                addLog("正在获取内容...")
                
                let (feedTitle, parsedArticles) = try await RSSParser.fetchAndParse(url: url, source: source)
                
                addLog("获取成功，标题: \(feedTitle)")
                addLog("解析到 \(parsedArticles.count) 篇文章")
                
                await MainActor.run {
                    articles = parsedArticles
                    isRunning = false
                }
                
                for (index, article) in parsedArticles.prefix(5).enumerated() {
                    addLog("[\(index + 1)] \(article.title)")
                }
                
            } catch {
                addLog("错误: \(error.localizedDescription)")
                await MainActor.run {
                    isRunning = false
                }
            }
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DispatchQueue.main.async {
            debugLog.append("[\(timestamp)] \(message)")
        }
    }
}