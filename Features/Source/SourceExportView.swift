import SwiftUI
import UniformTypeIdentifiers

struct SourceExportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SourceViewModel()
    
    @State private var selectedSources: Set<UUID> = []
    @State private var exportedJSON: String = ""
    @State private var showShareSheet = false
    @State private var exportFileName = "book_sources"
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Button("全选") {
                            selectedSources = Set(viewModel.sources.map { $0.sourceId })
                        }
                        Button("取消全选") {
                            selectedSources.removeAll()
                        }
                    }
                }
                
                Section("已选择 \(selectedSources.count) 个书源") {
                    ForEach(viewModel.sources, id: \.sourceId) { source in
                        Button(action: {
                            if selectedSources.contains(source.sourceId) {
                                selectedSources.remove(source.sourceId)
                            } else {
                                selectedSources.insert(source.sourceId)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedSources.contains(source.sourceId) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedSources.contains(source.sourceId) ? .blue : .gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.bookSourceName)
                                        .foregroundColor(.primary)
                                    Text(source.bookSourceGroup ?? "未分组")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    TextField("文件名", text: $exportFileName)
                    
                    Button(action: exportSelected) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("导出选中书源")
                        }
                    }
                    .disabled(selectedSources.isEmpty)
                    
                    Button(action: exportAll) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("导出全部书源")
                        }
                    }
                    .disabled(viewModel.sources.isEmpty)
                }
            }
            .navigationTitle("导出书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [exportedJSON])
            }
            .task {
                await viewModel.loadSources()
            }
        }
    }
    
    private func exportSelected() {
        let sourcesToExport = viewModel.sources.filter { selectedSources.contains($0.sourceId) }
        exportSources(sourcesToExport)
    }
    
    private func exportAll() {
        exportSources(viewModel.sources)
    }
    
    private func exportSources(_ sources: [BookSource]) {
        let exportData = sources.map { ExportableSource(from: $0) }
        
        guard let jsonData = try? JSONEncoder().encode(exportData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        exportedJSON = jsonString
        showShareSheet = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ExportableSource: Codable {
    let bookSourceUrl: String
    let bookSourceName: String
    let bookSourceGroup: String?
    let bookSourceType: Int?
    let searchUrl: String?
    let exploreUrl: String?
    let enabled: Bool
    let enabledExplore: Bool
    let weight: Int?
    let lastUpdateTime: Int64?
    let respondTime: Int?
    let loginUrl: String?
    let loginUi: String?
    let loginCheckJs: String?
    let header: String?
    let concurrentRate: String?
    
    init(from source: BookSource) {
        self.bookSourceUrl = source.bookSourceUrl
        self.bookSourceName = source.bookSourceName
        self.bookSourceGroup = source.bookSourceGroup
        self.bookSourceType = Int(source.bookSourceType)
        self.searchUrl = source.searchUrl
        self.exploreUrl = source.exploreUrl
        self.enabled = source.enabled
        self.enabledExplore = source.enabledExplore
        self.weight = Int(source.weight)
        self.lastUpdateTime = source.lastUpdateTime
        self.respondTime = source.respondTime
        self.loginUrl = source.loginUrl
        self.loginUi = source.loginUi
        self.loginCheckJs = source.loginCheckJs
        self.header = source.header
        self.concurrentRate = source.concurrentRate
    }
}