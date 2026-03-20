import SwiftUI

struct FileManageView: View {
    @State private var files: [URL] = []
    @State private var currentPath: URL?
    @State private var showingImporter = false
    
    private let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    
    var body: some View {
        List {
            if let currentPath = currentPath, currentPath != documentsDir {
                Button(action: { navigateUp() }) {
                    Label("..", systemImage: "arrow.up.folder")
                }
            }
            
            ForEach(files, id: \.self) { url in
                Button(action: { handleFile(url) }) {
                    HStack {
                        Image(systemName: url.hasDirectoryPath ? "folder.fill" : "doc.fill")
                            .foregroundColor(url.hasDirectoryPath ? .blue : .gray)
                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent)
                                .foregroundColor(.primary)
                            if !url.hasDirectoryPath {
                                Text(fileSize(url))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("文件管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingImporter = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result {
                copyFileToDocuments(url)
            }
        }
        .onAppear { loadFiles() }
    }
    
    private func loadFiles() {
        guard let dir = currentPath ?? documentsDir else { return }
        do {
            files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            files = []
        }
    }
    
    private func navigateUp() {
        currentPath = currentPath?.deletingLastPathComponent()
        loadFiles()
    }
    
    private func handleFile(_ url: URL) {
        if url.hasDirectoryPath {
            currentPath = url
            loadFiles()
        }
    }
    
    private func fileSize(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private func copyFileToDocuments(_ sourceURL: URL) {
        guard let documentsDir = documentsDir else { return }
        let destinationURL = documentsDir.appendingPathComponent(sourceURL.lastPathComponent)
        
        let granted = sourceURL.startAccessingSecurityScopedResource()
        defer { if granted { sourceURL.stopAccessingSecurityScopedResource() } }
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            loadFiles()
        } catch {
            print("Copy error: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        FileManageView()
    }
}