import SwiftUI
import CoreData

struct RemoteBookView: View {
    @StateObject private var viewModel = RemoteBookViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddServer = false
    @State private var selectedFile: WebDAVFile?
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.servers.isEmpty {
                    emptyServerView
                } else if viewModel.isLoading {
                    ProgressView("加载中...")
                } else if let files = viewModel.currentFiles {
                    fileListView(files)
                } else {
                    serverListView
                }
            }
            .navigationTitle("远程书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddServer = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                WebDAVConfigView()
            }
            .task {
                await viewModel.loadServers()
            }
        }
    }
    
    private var emptyServerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.icloud")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无 WebDAV 服务器")
                .foregroundColor(.secondary)
            Button("添加服务器") {
                showingAddServer = true
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var serverListView: some View {
        List(viewModel.servers) { server in
            Button(action: { Task { await viewModel.connectServer(server) } }) {
                HStack {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text(server.name)
                            .foregroundColor(.primary)
                        Text(server.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func fileListView(_ files: [WebDAVFile]) -> some View {
        List {
            if viewModel.currentPath != "/" {
                Button(action: { viewModel.navigateUp() }) {
                    Label("返回上级", systemImage: "chevron.left")
                }
            }
            
            ForEach(files, id: \.path) { file in
                if file.isDirectory {
                    Button(action: { viewModel.navigateTo(file.path) }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(file.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if isSupportedFile(file.name) {
                    Button(action: { selectedFile = file }) {
                        HStack {
                            Image(systemName: fileIcon(for: file.name))
                                .foregroundColor(fileColor(for: file.name))
                            VStack(alignment: .leading) {
                                Text(file.name)
                                    .foregroundColor(.primary)
                                Text(formatFileSize(file.size))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .alert("导入书籍", isPresented: .init(
            get: { selectedFile != nil },
            set: { if !$0 { selectedFile = nil } }
        )) {
            Button("取消", role: .cancel) { selectedFile = nil }
            Button("导入") {
                if let file = selectedFile {
                    Task { await viewModel.importFile(file) }
                }
            }
        } message: {
            Text("确定要导入「\(selectedFile?.name ?? "")」吗？")
        }
    }
    
    private func isSupportedFile(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["txt", "epub", "json"].contains(ext)
    }
    
    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "epub": return "book.fill"
        case "txt": return "doc.text.fill"
        case "json": return "doc.badge.gearshape"
        default: return "doc.fill"
        }
    }
    
    private func fileColor(for name: String) -> Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "epub": return .purple
        case "txt": return .blue
        case "json": return .orange
        default: return .gray
        }
    }
    
    private func formatFileSize(_ bytes: Int64?) -> String {
        guard let bytes = bytes else { return "未知大小" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}

@MainActor
class RemoteBookViewModel: ObservableObject {
    @Published var servers: [WebDAVCredentials] = []
    @Published var currentFiles: [WebDAVFile]?
    @Published var currentPath = "/"
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentClient: WebDAVClient?
    
    func loadServers() async {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<WebDAVCredentials> = WebDAVCredentials.fetchRequest()
        
        do {
            servers = try context.fetch(request)
        } catch {
            errorMessage = "加载服务器失败：\(error.localizedDescription)"
        }
    }
    
    func connectServer(_ server: WebDAVCredentials) async {
        guard let url = URL(string: server.url) else { return }
        
        isLoading = true
        currentClient = WebDAVClient(baseURL: url, credentials: server)
        currentPath = "/"
        
        do {
            currentFiles = try await currentClient?.list(path: "/")
        } catch {
            errorMessage = "连接失败：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func navigateTo(_ path: String) {
        currentPath = path
        Task {
            isLoading = true
            do {
                currentFiles = try await currentClient?.list(path: path)
            } catch {
                errorMessage = "加载失败：\(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    func navigateUp() {
        let components = currentPath.split(separator: "/")
        if components.count > 1 {
            let newPath = "/" + components.dropLast().joined(separator: "/")
            navigateTo(newPath.isEmpty ? "/" : newPath)
        } else {
            currentFiles = nil
            currentPath = "/"
        }
    }
    
    func importFile(_ file: WebDAVFile) async {
        guard let client = currentClient else { return }
        
        isLoading = true
        do {
            let localURL = try await client.download(path: file.path)
            
            let ext = (file.name as NSString).pathExtension.lowercased()
            if ext == "json" {
                let data = try Data(contentsOf: localURL)
                if let jsonString = String(data: data, encoding: .utf8) {
                    URLSchemeHandler.importBookSourceJSON(jsonString) { _ in }
                }
            } else {
                let localBookVM = LocalBookViewModel()
                try await localBookVM.importBook(url: localURL)
            }
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
        isLoading = false
    }
}