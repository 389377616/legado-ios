import SwiftUI
import CoreData

struct ShareViewController: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sharedText: String = ""
    @State private var sharedURL: String = ""
    @State private var isProcessing = false
    @State private var resultMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                if !sharedText.isEmpty {
                    Section("分享内容") {
                        Text(sharedText)
                            .font(.caption)
                    }
                }
                
                if !sharedURL.isEmpty {
                    Section("分享链接") {
                        Text(sharedURL)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Section {
                    Button(action: addToBookshelf) {
                        HStack {
                            Image(systemName: "books.vertical")
                            Text("添加到书架")
                        }
                    }
                    .disabled(sharedURL.isEmpty)
                    
                    Button(action: importAsSource) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("导入为书源")
                        }
                    }
                    .disabled(sharedText.isEmpty && sharedURL.isEmpty)
                }
                
                if let message = resultMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(message.contains("成功") ? .green : .red)
                    }
                }
            }
            .navigationTitle("Legado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            loadSharedContent()
        }
    }
    
    private func loadSharedContent() {
        guard let extensionContext = ExtensionContextProvider.shared.extensionContext,
              let items = extensionContext.inputItems as? [NSExtensionItem] else {
            return
        }
        
        for item in items {
            if let textProvider = item.attachments?.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.text.identifier) }) {
                textProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                    if let text = data as? String {
                        DispatchQueue.main.async {
                            self.sharedText = text
                        }
                    }
                }
            }
            
            if let urlProvider = item.attachments?.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
                urlProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                    if let url = data as? URL {
                        DispatchQueue.main.async {
                            self.sharedURL = url.absoluteString
                        }
                    }
                }
            }
        }
    }
    
    private func addToBookshelf() {
        guard !sharedURL.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            do {
                let context = CoreDataStack.shared.viewContext
                let book = Book.create(in: context)
                book.name = sharedURL
                book.bookUrl = sharedURL
                book.origin = "分享添加"
                try context.save()
                
                await MainActor.run {
                    resultMessage = "已添加到书架"
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    resultMessage = "添加失败: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    private func importAsSource() {
        let jsonContent = sharedText.isEmpty ? sharedURL : sharedText
        
        guard !jsonContent.isEmpty else { return }
        
        isProcessing = true
        
        URLSchemeHandler.importBookSourceJSON(jsonContent) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    resultMessage = message
                case .failure(let error):
                    resultMessage = "导入失败: \(error.localizedDescription)"
                }
                isProcessing = false
            }
        }
    }
}

class ExtensionContextProvider {
    static let shared = ExtensionContextProvider()
    var extensionContext: NSExtensionContext?
}

import UniformTypeIdentifiers