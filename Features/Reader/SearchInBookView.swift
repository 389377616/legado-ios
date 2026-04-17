import SwiftUI
import CoreData

struct SearchInBookView: View {
    let book: Book
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [InBookSearchResult] = []
    @State private var isSearching = false
    
    struct InBookSearchResult: Identifiable {
        let id = UUID()
        let chapterIndex: Int
        let chapterTitle: String
        let lineNumber: Int
        let matchedText: String
        let range: Range<String.Index>
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("在书中搜索...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; searchResults = [] }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button("搜索") {
                        performSearch()
                    }
                    .disabled(searchText.isEmpty || isSearching)
                }
                .padding()
                .background(Color(.systemBackground))
                
                if isSearching {
                    VStack {
                        ProgressView("搜索中...")
                            .padding()
                        Text("正在搜索章节内容...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty {
                    if searchText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("输入关键词搜索书中内容")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("未找到相关内容")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    List {
                        Text("找到 \(searchResults.count) 个结果")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(searchResults) { result in
                            Button(action: { jumpToResult(result) }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(result.chapterTitle)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("第\(result.chapterIndex + 1)章")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text(highlightedText(result.matchedText, search: searchText))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("书内搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        Task {
            let context = CoreDataStack.shared.viewContext
            let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
            request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
            
            guard let chapters = try? context.fetch(request) else {
                await MainActor.run { isSearching = false }
                return
            }
            
            var results: [InBookSearchResult] = []
            let searchLower = searchText.lowercased()
            
            for chapter in chapters {
                guard let content = BookHelp.getContent(book, chapter) else { continue }
                let contentLower = content.lowercased()
                
                var searchStartIndex = contentLower.startIndex
                var lineNumber = 0
                
                while let range = contentLower.range(of: searchLower, range: searchStartIndex..<contentLower.endIndex) {
                    let start = content.index(range.lowerBound, offsetBy: -20, limitedBy: content.startIndex) ?? content.startIndex
                    let end = content.index(range.upperBound, offsetBy: 20, limitedBy: content.endIndex) ?? content.endIndex
                    
                    let matchedText = String(content[start..<end])
                    
                    results.append(InBookSearchResult(
                        chapterIndex: Int(chapter.index),
                        chapterTitle: chapter.title ?? "",
                        lineNumber: lineNumber,
                        matchedText: matchedText,
                        range: range
                    ))
                    
                    searchStartIndex = range.upperBound
                    lineNumber += 1
                    
                    if results.count >= 100 { break }
                }
                
                if results.count >= 100 { break }
            }
            
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }
    
    private func highlightedText(_ text: String, search: String) -> AttributedString {
        var result = AttributedString(text)
        let lowercased = text.lowercased()
        let searchLower = search.lowercased()
        
        if let range = lowercased.range(of: searchLower),
           let attrRange = Range(range, in: result) {
            result[attrRange].backgroundColor = .yellow
        }
        
        return result
    }
    
    private func jumpToResult(_ result: InBookSearchResult) {
        NotificationCenter.default.post(
            name: Notification.Name("JumpToChapter"),
            object: nil,
            userInfo: ["chapterIndex": result.chapterIndex]
        )
        dismiss()
    }
}