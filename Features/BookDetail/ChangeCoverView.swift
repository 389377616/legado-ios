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
                        if let coverUrlStr = book.displayCoverUrl, let url = URL(string: coverUrlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFit()
                                        .frame(width: 120, height: 160).cornerRadius(8)
                                case .failure(_), .empty:
                                    Image(systemName: "book.closed")
                                        .font(.system(size: 60)).foregroundColor(.secondary)
                                        .frame(width: 120, height: 160)
                                @unknown default:
                                    EmptyView()
                                }
                            }
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
                                ForEach(searchResults) { result in
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
                        
                        List(searchResults) { result in
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
        // Save image to a temporary file and use the URL
        if let data = imageData {
            let fileName = "cover_\(book.bookId).jpg"
            if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = docsDir.appendingPathComponent("covers").appendingPathComponent(fileName)
                try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: fileURL)
                book.customCoverUrl = fileURL.absoluteString
                try? CoreDataStack.shared.save()
                onCoverChanged()
            }
        }
    }
    
    private func clearCover() {
        book.customCoverUrl = nil
        try? CoreDataStack.shared.save()
        onCoverChanged()
    }
    
    private func searchCovers() {
        isSearching = true
        
        Task {
            do {
                let keyword = "\(book.name) \(book.author) 封面"
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

struct CoverSearchResult: Identifiable {
    var id: String { coverUrl }
    let name: String
    let author: String
    let coverUrl: String
    let source: String
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
        guard let url = URL(string: result.coverUrl) else { return }
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.image = uiImage
                    }
                }
            } catch {
                DebugLogger.shared.error("ChangeCover load image failed: \(error.localizedDescription)")
            }
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

/// 封面搜索服务 — 对标安卓 coverRule.json
/// 通过推书君等公开API按书名+作者搜索封面
class CoverSearchService {
    /// 推书君封面搜索API（对标安卓 CoverRule 第一条规则）
    private static let tuiShuJunURL = "https://www.tuishujun.com/api/search"
    /// YP书说封面搜索API（对标安卓 CoverRule 第二条规则）
    private static let ypShuShuoURL = "https://www.ypshuoshuo.com/api/search"

    /// 搜索封面（对标安卓 BookHelp.getBookCoverBySearch）
    /// - Parameter keyword: 搜索关键词（书名 或 书名+作者）
    /// - Returns: 搜索结果列表
    static func search(keyword: String) async throws -> [CoverSearchResult] {
        guard !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var allResults: [CoverSearchResult] = []

        // 并发搜索多个来源
        async let tuiResults = searchTuiShuJun(keyword: keyword)
        async let ypResults = searchYPShuShuo(keyword: keyword)

        let (tui, yp) = try await (tuiResults, ypResults)
        allResults.append(contentsOf: tui)
        allResults.append(contentsOf: yp)

        // 去重（按coverUrl）
        var seen = Set<String>()
        return allResults.filter { result in
            guard !result.coverUrl.isEmpty, !seen.contains(result.coverUrl) else { return false }
            seen.insert(result.coverUrl)
            return true
        }
    }

    // MARK: - 推书君搜索（对标安卓 coverRule 第一条JS脚本）

    private static func searchTuiShuJun(keyword: String) async throws -> [CoverSearchResult] {
        guard let url = URL(string: "\(tuiShuJunURL)?keyword=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            return []
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        // 解析推书君API响应
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let books = json["data"] as? [[String: Any]] else {
            return []
        }

        return books.compactMap { book -> CoverSearchResult? in
            guard let name = book["name"] as? String,
                  let coverUrl = book["coverUrl"] as? String, !coverUrl.isEmpty else { return nil }
            let author = book["author"] as? String
            return CoverSearchResult(
                name: name,
                author: author ?? "",
                coverUrl: coverUrl,
                source: "推书君"
            )
        }
    }

    // MARK: - YP书说搜索（对标安卓 coverRule 第二条JS脚本）

    private static func searchYPShuShuo(keyword: String) async throws -> [CoverSearchResult] {
        guard let url = URL(string: "\(ypShuShuoURL)?keyword=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            return []
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let books = json["data"] as? [[String: Any]] else {
            return []
        }

        return books.compactMap { book -> CoverSearchResult? in
            guard let name = book["name"] as? String,
                  let coverUrl = book["coverUrl"] as? String, !coverUrl.isEmpty else { return nil }
            let author = book["author"] as? String
            return CoverSearchResult(
                name: name,
                author: author ?? "",
                coverUrl: coverUrl,
                source: "YP书说"
            )
        }
    }

    // MARK: - 本地搜索回退（对标安卓 CoverRule 的本地匹配逻辑）

    /// 从已导入书源中搜索封面（使用书源规则）
    /// - Parameters:
    ///   - name: 书名
    ///   - author: 作者
    /// - Returns: 匹配的封面URL
    static func searchFromSources(name: String, author: String) async -> String? {
        let context = CoreDataStack.shared.viewContext
        let request = BookSource.fetchRequest() as NSFetchRequest<BookSource>
        request.predicate = NSPredicate(format: "enabled == YES AND ruleBookInfoData != nil")
        request.fetchLimit = 5

        guard let sources = try? context.fetch(request), !sources.isEmpty else { return nil }

        // 尝试每个启用的书源查找封面
        for source in sources {
            guard let searchUrl = source.searchUrl, !searchUrl.isEmpty else { continue }

            let keyword = author.isEmpty ? name : "\(name) \(author)"
            let urlString = searchUrl
                .replacingOccurrences(of: "{{key}}", with: keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)

            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { continue }

                // 尝试解析搜索结果中的封面URL
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["data"] as? [[String: Any]] {
                    for result in results {
                        if let coverUrl = result["coverUrl"] as? String, !coverUrl.isEmpty {
                            return coverUrl
                        }
                    }
                }
            } catch {
                continue
            }
        }

        return nil
    }
}

#Preview {
    ChangeCoverView(book: Book.create(in: CoreDataStack.shared.viewContext), onCoverChanged: {})
}
