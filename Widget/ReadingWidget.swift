import SwiftUI
import WidgetKit

struct ReadingProgressWidget: Widget {
    var body: some Widget {
        StaticConfiguration(kind: "ReadingProgress", provider: ReadingProgressTimelineProvider()) { entry in
            ReadingProgressEntryView(entry: entry)
        }
        .configurationDisplayName("阅读进度")
        .description("显示最近阅读的书籍进度")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ReadingProgressEntry: TimelineEntry {
    let date: Date
    let bookName: String
    let author: String
    let chapterTitle: String
    let progress: Double
}

struct ReadingProgressTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingProgressEntry {
        ReadingProgressEntry(date: Date(), bookName: "示例书籍", author: "作者", chapterTitle: "第一章", progress: 0.35)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ReadingProgressEntry) -> Void) {
        let entry = ReadingProgressEntry(date: Date(), bookName: "示例书籍", author: "作者", chapterTitle: "第一章", progress: 0.35)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingProgressEntry>) -> Void) {
        let entry = loadRecentBook()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadRecentBook() -> ReadingProgressEntry {
        let defaults = UserDefaults(suiteName: "group.com.chrn11.legado")
        let bookName = defaults?.string(forKey: "widget_bookName") ?? "暂无阅读"
        let author = defaults?.string(forKey: "widget_author") ?? ""
        let chapterTitle = defaults?.string(forKey: "widget_chapterTitle") ?? ""
        let progress = defaults?.double(forKey: "widget_progress") ?? 0
        
        return ReadingProgressEntry(date: Date(), bookName: bookName, author: author, chapterTitle: chapterTitle, progress: progress)
    }
}

struct ReadingProgressEntryView: View {
    let entry: ReadingProgressEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.bookName)
                    .font(.headline)
                    .lineLimit(1)
                
                ProgressView(value: entry.progress)
                    .progressViewStyle(.linear)
                
                Text("\(Int(entry.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
        case .systemMedium:
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.bookName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if !entry.author.isEmpty {
                        Text(entry.author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(entry.chapterTitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: entry.progress)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(entry.progress * 100))%")
                            .font(.caption2)
                            .bold()
                    }
                    .frame(width: 50, height: 50)
                }
            }
            .padding()
            
        default:
            Text(entry.bookName)
        }
    }
}

struct BookshelfWidget: Widget {
    var body: some Widget {
        StaticConfiguration(kind: "Bookshelf", provider: BookshelfTimelineProvider()) { entry in
            BookshelfEntryView(entry: entry)
        }
        .configurationDisplayName("书架")
        .description("显示最近更新的书籍")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct BookshelfEntry: TimelineEntry {
    let date: Date
    let books: [BookInfo]
    
    struct BookInfo {
        let name: String
        let latestChapter: String
    }
}

struct BookshelfTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BookshelfEntry {
        BookshelfEntry(date: Date(), books: [
            .init(name: "示例书籍1", latestChapter: "第100章"),
            .init(name: "示例书籍2", latestChapter: "第50章")
        ])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (BookshelfEntry) -> Void) {
        completion(placeholder(in: context))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<BookshelfEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.chrn11.legado")
        var books: [BookshelfEntry.BookInfo] = []
        
        if let names = defaults?.stringArray(forKey: "widget_bookNames"),
           let chapters = defaults?.stringArray(forKey: "widget_latestChapters") {
            for i in 0..<min(names.count, chapters.count) {
                books.append(.init(name: names[i], latestChapter: chapters[i]))
            }
        }
        
        let entry = BookshelfEntry(date: Date(), books: books.isEmpty ? placeholder(in: context).books : books)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct BookshelfEntryView: View {
    let entry: BookshelfEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("书架更新")
                .font(.headline)
            
            ForEach(entry.books.prefix(family == .systemMedium ? 2 : 5), id: \.name) { book in
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.name)
                            .font(.caption)
                            .lineLimit(1)
                        Text(book.latestChapter)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}