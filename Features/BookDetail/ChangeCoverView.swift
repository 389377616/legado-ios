import SwiftUI
import PhotosUI

struct ChangeCoverView: View {
    @Environment(\.dismiss) private var dismiss
    let book: Book
    let onCoverChanged: () -> Void
    
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingSearchCover = false
    @State private var searchKeyword = ""
    @State private var searchResults: [CoverSearchResult] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("当前封面")) {
                    HStack {
                        Spacer()
                        if let coverData = book.cover, let uiImage = UIImage(data: coverData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 160)
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                                .frame(width: 120, height: 160)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
                
                Section(header: Text("更换封面")) {
                    Button(action: { showingImagePicker = true }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.blue)
                            Text("从相册选择")
                        }
                    }
                    
                    Button(action: { showingSearchCover = true }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                            Text("搜索封面")
                        }
                    }
                    
                    Button(action: clearCover) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("清除封面")
                        }
                    }
                }
                
                if !searchResults.isEmpty {
                    Section(header: Text("搜索结果")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(searchResults, id: \.url) { result in
                                    CoverResultItem(result: result) { image in
                                        applyCover(image)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("更换封面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        if let image = selectedImage {
                            applyCover(image)
                        }
                        dismiss()
                    }
                    .disabled(selectedImage == nil)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $showingSearchCover) {
                NavigationView {
                    VStack {
                        TextField("输入书名或作者", text: $searchKeyword)
                            .textFieldStyle(.roundedBorder)
                            .padding()
                        
                        Button("搜索") {
                            searchCovers()
                        }
                        .disabled(searchKeyword.isEmpty || isSearching)
                        
                        if isSearching {
                            ProgressView()
                                .padding()
                        }
                        
                        List(searchResults, id: \.url) { result in
                            CoverResultItem(result: result) { image in
                                applyCover(image)
                                showingSearchCover = false
                            }
                        }
                    }
                    .navigationTitle("搜索封面")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("取消") { showingSearchCover = false }
                        }
                    }
                }
            }
        }
    }
    
    private func applyCover(_ image: UIImage) {
        let imageData = image.jpegData(compressionQuality: 0.8)
        book.cover = imageData
        try? CoreDataStack.shared.save()
        onCoverChanged()
    }
    
    private func clearCover() {
        book.cover = nil
        try? CoreDataStack.shared.save()
        onCoverChanged()
    }
    
    private func searchCovers() {
        isSearching = true
        
        Task {
            do {
                let keyword = "\(book.name) \(book.author ?? "") 封面"
                let results = try await CoverSearchService.search(keyword: keyword)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                }
            }
        }
    }
}

struct CoverSearchResult {
    let url: String
    let thumbnailURL: String?
}

struct CoverResultItem: View {
    let result: CoverSearchResult
    let onSelect: (UIImage) -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 100)
                    .cornerRadius(4)
                    .onTapGesture {
                        onSelect(image)
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 100)
                    .cornerRadius(4)
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = URL(string: result.thumbnailURL ?? result.url) else { return }
        
        Task {
            do {
                let data = try Data(contentsOf: url)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.image = uiImage
                    }
                }
            } catch {}
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.image = image
                    }
                }
            }
        }
    }
}

class CoverSearchService {
    static func search(keyword: String) async throws -> [CoverSearchResult] {
        return []
    }
}

#Preview {
    ChangeCoverView(book: Book.create(in: CoreDataStack.shared.viewContext), onCoverChanged: {})
}