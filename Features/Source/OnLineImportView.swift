import SwiftUI

struct OnLineImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var isImporting = false
    @State private var importResult: String?
    @State private var importedCount = 0
    
    var body: some View {
        NavigationView {
            Form {
                Section("在线导入") {
                    TextField("输入书源JSON地址", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Button(action: importFromUrl) {
                        HStack {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("导入")
                        }
                    }
                    .disabled(urlText.isEmpty || isImporting)
                }
                
                Section("常用书源地址") {
                    ForEach(commonSourceUrls, id: \.0) { (name, url) in
                        Button(action: { urlText = url }) {
                            HStack {
                                Text(name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if let result = importResult {
                    Section("结果") {
                        Text(result)
                            .font(.subheadline)
                            .foregroundColor(result.contains("成功") ? .green : .red)
                    }
                }
                
                Section("说明") {
                    Text("支持导入 JSON 格式的书源文件，可以是单个书源或书源数组。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("在线导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
    
    private var commonSourceUrls: [(String, String)] {
        [
            ("开源书源库", "https://raw.githubusercontent.com/gedoor/legado/main/app/src/main/assets/importBookSource.json"),
            ("Legado社区", "https://legado.top/sources")
        ]
    }
    
    private func importFromUrl() {
        guard !urlText.isEmpty, !isImporting else { return }
        
        isImporting = true
        importResult = nil
        
        Task {
            do {
                var url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
                    url = "https://" + url
                }
                
                guard let sourceURL = URL(string: url) else {
                    await MainActor.run {
                        importResult = "无效的URL地址"
                        isImporting = false
                    }
                    return
                }
                
                let (data, _) = try await URLSession.shared.data(from: sourceURL)
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    await MainActor.run {
                        importResult = "无法读取文件内容"
                        isImporting = false
                    }
                    return
                }
                
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    URLSchemeHandler.importBookSourceJSON(jsonString) { result in
                        switch result {
                        case .success(let message):
                            importResult = message
                        case .failure(let error):
                            importResult = "导入失败: \(error.localizedDescription)"
                        }
                        continuation.resume()
                    }
                }
                
                await MainActor.run {
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    importResult = "网络错误: \(error.localizedDescription)"
                    isImporting = false
                }
            }
        }
    }
}