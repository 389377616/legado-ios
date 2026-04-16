import SwiftUI

struct FontSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReaderViewModel
    @Binding var isPresented: Bool
    
    @State private var selectedFontType: FontManager.ChineseFontType = .songti
    @State private var customFontName: String = ""
    @State private var showingFontPicker = false
    
    private let fontTypes: [FontManager.ChineseFontType] = FontManager.ChineseFontType.allCases
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("系统字体")) {
                    ForEach(fontTypes, id: \.self) { type in
                        Button(action: { selectFontType(type) }) {
                            HStack {
                                Text(type.rawValue)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedFontType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("字号设置")) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("字号")
                            Spacer()
                            Text("\(Int(viewModel.fontSize))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $viewModel.fontSize, in: 12...32, step: 1)
                        
                        HStack(spacing: 12) {
                            ForEach([14, 16, 18, 20, 22, 24], id: \.self) { size in
                                Button(action: { viewModel.fontSize = CGFloat(size) }) {
                                    Text("\(size)")
                                        .font(.system(size: CGFloat(size)))
                                        .frame(width: 40, height: 30)
                                        .background(viewModel.fontSize == CGFloat(size) ? Color.blue.opacity(0.2) : Color.clear)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("行间距")) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("行间距")
                            Spacer()
                            Text("\(Int(viewModel.lineSpacing))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $viewModel.lineSpacing, in: 4...20, step: 1)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("段间距")) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("段间距")
                            Spacer()
                            Text("\(Int(viewModel.paragraphSpacing))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $viewModel.paragraphSpacing, in: 8...24, step: 2)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("字间距")) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("字间距")
                            Spacer()
                            Text("\(Int(viewModel.letterSpacing))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $viewModel.letterSpacing, in: 0...5, step: 0.5)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("自定义字体")) {
                    Button(action: { showingFontPicker = true }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.blue)
                            Text("导入字体文件")
                        }
                    }
                    
                    if !customFontName.isEmpty {
                        HStack {
                            Text("当前字体")
                            Spacer()
                            Text(customFontName)
                                .foregroundColor(.secondary)
                            
                            Button(action: { removeCustomFont() }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section(header: Text("预览")) {
                    Text("这是字体预览文本，用于展示当前字体设置效果。阅读是一种美好的体验，让我们享受文字带来的乐趣。")
                        .font(.custom(getCurrentFontName(), size: viewModel.fontSize))
                        .lineSpacing(viewModel.lineSpacing)
                        .padding()
                        .background(viewModel.backgroundColor)
                        .foregroundColor(viewModel.textColor)
                }
            }
            .navigationTitle("字体设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFontPicker) {
                DocumentPicker(onPick: importCustomFont)
            }
        }
    }
    
    private func getCurrentFontName() -> String {
        if !customFontName.isEmpty {
            return customFontName
        }
        return selectedFontType.systemFontName
    }
    
    private func selectFontType(_ type: FontManager.ChineseFontType) {
        selectedFontType = type
        customFontName = ""
    }
    
    private func importCustomFont(url: URL) {
        let filename = url.lastPathComponent
        
        if FontManager.shared.copyFontToDocuments(from: url, filename: filename) {
            customFontName = url.deletingPathExtension().lastPathComponent
        }
    }
    
    private func removeCustomFont() {
        customFontName = ""
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedFontType.rawValue, forKey: "reader.fontType")
        UserDefaults.standard.set(customFontName, forKey: "reader.customFontName")
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.init(filenameExtension: "ttf")!, .init(filenameExtension: "otf")!], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}

#Preview {
    FontSettingsView(
        viewModel: ReaderViewModel(),
        isPresented: .constant(true)
    )
}