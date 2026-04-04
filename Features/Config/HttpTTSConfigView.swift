import SwiftUI
import CoreData

struct HttpTTSConfigView: View {
    @StateObject private var viewModel = HttpTTSViewModel()
    @State private var showingEditor = false
    @State private var editingTTS: HttpTTS?
    
    var body: some View {
        List {
            if viewModel.engines.isEmpty {
                emptyView
            } else {
                ForEach(viewModel.engines, id: \.id) { engine in
                    HttpTTSRow(engine: engine) {
                        editingTTS = engine
                        showingEditor = true
                    }
                }
                .onDelete { indexSet in
                    viewModel.deleteEngines(at: indexSet)
                }
            }
        }
        .navigationTitle("在线TTS")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    editingTTS = nil
                    showingEditor = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor, onDismiss: {
            Task { await viewModel.loadEngines() }
        }) {
            NavigationStack {
                HttpTTSEditorView(engine: editingTTS)
            }
        }
        .task { await viewModel.loadEngines() }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "speaker.wave.3")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            Text("暂无在线TTS引擎")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("点击右上角 + 添加引擎")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HttpTTSRow: View {
    let engine: HttpTTS
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(engine.name)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Circle()
                            .fill(engine.enabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(engine.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.primary)
    }
}

struct HttpTTSEditorView: View {
    let engine: HttpTTS?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var header = ""
    @State private var loginUrl = ""
    @State private var loginUi = ""
    @State private var loginCheckJs = ""
    @State private var contentType = ""
    @State private var concurrentRate = ""
    @State private var enabled = true
    
    var body: some View {
        Form {
            Section(header: Text("基本信息")) {
                TextField("名称", text: $name)
                TextField("URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("启用", isOn: $enabled)
            }
            
            Section(header: Text("请求配置")) {
                TextField("Header (JSON)", text: $header, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(.body, design: .monospaced))
                TextField("Content-Type", text: $contentType)
                TextField("并发率限制", text: $concurrentRate)
            }
            
            Section(header: Text("登录配置")) {
                TextField("登录URL", text: $loginUrl)
                TextField("登录UI", text: $loginUi)
                TextField("登录检查JS", text: $loginCheckJs, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(.body, design: .monospaced))
            }
            
            Section {
                Button("保存") {
                    saveEngine()
                }
                .disabled(name.isEmpty || url.isEmpty)
            }
        }
        .navigationTitle(engine == nil ? "添加TTS引擎" : "编辑TTS引擎")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") { dismiss() }
            }
        }
        .onAppear {
            if let engine = engine {
                name = engine.name
                url = engine.url
                header = engine.header ?? ""
                loginUrl = engine.loginUrl ?? ""
                loginUi = engine.loginUi ?? ""
                loginCheckJs = engine.loginCheckJs ?? ""
                contentType = engine.contentType ?? ""
                concurrentRate = engine.concurrentRate ?? ""
                enabled = engine.enabled
            }
        }
    }
    
    private func saveEngine() {
        let context = CoreDataStack.shared.viewContext
        
        let tts: HttpTTS
        if let existing = engine {
            tts = existing
        } else {
            tts = HttpTTS.create(in: context)
        }
        
        tts.name = name
        tts.url = url
        tts.header = header.isEmpty ? nil : header
        tts.loginUrl = loginUrl.isEmpty ? nil : loginUrl
        tts.loginUi = loginUi.isEmpty ? nil : loginUi
        tts.loginCheckJs = loginCheckJs.isEmpty ? nil : loginCheckJs
        tts.contentType = contentType.isEmpty ? nil : contentType
        tts.concurrentRate = concurrentRate.isEmpty ? nil : concurrentRate
        tts.enabled = enabled
        
        do {
            try context.save()
            dismiss()
        } catch {
            DebugLogger.shared.log("保存TTS引擎失败: \(error)")
        }
    }
}

@MainActor
class HttpTTSViewModel: ObservableObject {
    @Published var engines: [HttpTTS] = []
    
    func loadEngines() async {
        let context = CoreDataStack.shared.viewContext
        let request = HttpTTS.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        engines = (try? context.fetch(request)) ?? []
    }
    
    func deleteEngines(at offsets: IndexSet) {
        let context = CoreDataStack.shared.viewContext
        for index in offsets {
            context.delete(engines[index])
        }
        try? context.save()
        engines.remove(atOffsets: offsets)
    }
}