import SwiftUI
import UniformTypeIdentifiers

struct FileAssociationHandler: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var fileType: FileType = .unknown
    @State private var isImporting = false
    @State private var importResult: String?
    
    enum FileType {
        case txt, epub, json, unknown
        
        var displayName: String {
            switch self {
            case .txt: return "TXT 文本"
            case .epub: return "EPUB 电子书"
            case .json: return "JSON 文件"
            case .unknown: return "未知类型"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("文件信息") {
                    HStack {
                        Text("文件名")
                        Spacer()
                        Text(url.lastPathComponent)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text("类型")
                        Spacer()
                        Text(fileType.displayName)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: importFile) {
                        HStack {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("导入到应用")
                        }
                    }
                    .disabled(isImporting || fileType == .unknown)
                    
                    Button(action: { shareFile() }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("分享文件")
                        }
                    }
                }
                
                if let result = importResult {
                    Section("结果") {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("成功") ? .green : .red)
                    }
                }
            }
            .navigationTitle("打开文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear {
            detectFileType()
        }
    }
    
    private func detectFileType() {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "txt":
            fileType = .txt
        case "epub":
            fileType = .epub
        case "json":
            fileType = .json
        default:
            fileType = .unknown
        }
    }
    
    private func importFile() {
        guard !isImporting else { return }
        isImporting = true
        importResult = nil
        
        Task {
            do {
                switch fileType {
                case .txt, .epub:
                    try await importBook()
                case .json:
                    try await importJson()
                case .unknown:
                    importResult = "不支持的文件类型"
                }
            } catch {
                importResult = "导入失败: \(error.localizedDescription)"
            }
            
            await MainActor.run {
                isImporting = false
            }
        }
    }
    
    private func importBook() async throws {
        let context = CoreDataStack.shared.viewContext
        
        let book = Book.create(in: context)
        book.name = url.deletingPathExtension().lastPathComponent
        book.author = "本地导入"
        book.bookUrl = url.absoluteString
        book.origin = "本地文件"
        book.originName = "本地文件"
        book.type = fileType == .epub ? 1 : 0
        
        try context.save()
        importResult = "成功添加到书架"
    }
    
    private func importJson() async throws {
        let data = try Data(contentsOf: url)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "FileAssociation", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取文件"])
        }
        
        let count: Int
        if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
            count = await importBookSources(jsonString)
        } else {
            count = await importBookSources(jsonString)
        }
        
        importResult = count > 0 ? "成功导入 \(count) 个书源" : "导入失败"
    }
    
    private func importBookSources(_ jsonString: String) async -> Int {
        var result: Int = 0
        await withCheckedContinuation { continuation in
            URLSchemeHandler.importBookSourceJSON(jsonString) { res in
                switch res {
                case .success:
                    result = 1
                case .failure:
                    result = 0
                }
                continuation.resume()
            }
        }
        return result
    }
    
    private func shareFile() {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}