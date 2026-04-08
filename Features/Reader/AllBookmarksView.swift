import SwiftUI
import CoreData

struct AllBookmarksView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bookmark.createdAt, ascending: false)],
        animation: .default)
    private var bookmarks: FetchedResults<Bookmark>
    
    var body: some View {
        List {
            ForEach(bookmarks, id: \.self) { bookmark in
                VStack(alignment: .leading, spacing: 4) {
                    Text(bookmark.bookName ?? "未知书籍")
                        .font(.headline)
                    Text("第 \(bookmark.chapterIndex) 章")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let content = bookmark.content, !content.isEmpty {
                        Text(content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .navigationTitle("全部书签")
        .navigationBarTitleDisplayMode(.inline)
    }
}