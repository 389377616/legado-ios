import SwiftUI
import WidgetKit
import Intents

// MARK: - 阅读进度小组件

struct ReadingProgressWidget: Widget {
    var body: some Widget {
        StaticConfiguration(kind: "ReadingProgress", provider: ReadingProgressTimelineProvider()) { entry in
            ReadingProgressEntryView(entry: entry)
        }
        .configurationDisplayName("阅读进度")
        .description("显示最近阅读的书籍进度")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular])
    }
}

struct ReadingProgressEntry: TimelineEntry {
    let date: Date
    let bookName: String
    let author: String
    let chapterTitle: String
    let progress: Double
    let totalChapters: Int
    let currentChapter: Int
}

struct ReadingProgressTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingProgressEntry {
        ReadingProgressEntry(date: Date(), bookName: "示例书籍", author: "作者", chapterTitle: "第一章", progress: 0.35, totalChapters: 100, currentChapter: 35)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingProgressEntry) -> Void) {
        completion(loadRecentBook())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingProgressEntry>) -> Void) {
        let entry = loadRecentBook()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadRecentBook() -> ReadingProgressEntry {
        let defaults = UserDefaults(suiteName: "group.com.chrn11.legado")
        return ReadingProgressEntry(
            date: Date(),
            bookName: defaults?.string(forKey: "widget_bookName") ?? "暂无阅读",
            author: defaults?.string(forKey: "widget_author") ?? "",
            chapterTitle: defaults?.string(forKey: "widget_chapterTitle") ?? "",
            progress: defaults?.double(forKey: "widget_progress") ?? 0,
            totalChapters: defaults?.integer(forKey: "widget_totalChapters") ?? 0,
            currentChapter: defaults?.integer(forKey: "widget_currentChapter") ?? 0
        )
    }
}

struct ReadingProgressEntryView: View {
    let entry: ReadingProgressEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        case .accessoryRectangular:
            rectangularView
        case .accessoryCircular:
            circularView
        default:
            Text(entry.bookName)
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.bookName)
                .font(.headline)
                .lineLimit(1)
                .foregroundColor(.primary)

            if !entry.author.isEmpty {
                Text(entry.author)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            ProgressView(value: entry.progress)
                .progressViewStyle(.linear)
                .tint(.blue)

            HStack {
                Text(entry.chapterTitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(entry.progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var mediumView: some View {
        HStack(spacing: 12) {
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
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if entry.totalChapters > 0 {
                    Text("第\(entry.currentChapter)/\(entry.totalChapters)章")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                ProgressView(value: entry.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(entry.progress * 100))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60, height: 60)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                Text("阅读进度")
                    .font(.headline)
            }

            Divider()

            Text(entry.bookName)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)

            if !entry.author.isEmpty {
                Text(entry.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前章节")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.chapterTitle)
                        .font(.subheadline)
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(entry.progress * 100))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
            }

            if entry.totalChapters > 0 {
                ProgressView(value: entry.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                HStack {
                    Text("第\(entry.currentChapter)章")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("共\(entry.totalChapters)章")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 6) {
            ProgressView(value: entry.progress)
                .progressViewStyle(.circular)
                .tint(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.bookName)
                    .font(.caption2)
                    .lineLimit(1)
                Text("\(Int(entry.progress * 100))% · \(entry.chapterTitle)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            ProgressView(value: entry.progress)
                .progressViewStyle(.circular)
                .tint(.blue)
            Text("\(Int(entry.progress * 100))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - 今日阅读统计小组件

struct ReadingStatsWidget: Widget {
    var body: some Widget {
        StaticConfiguration(kind: "ReadingStats", provider: ReadingStatsTimelineProvider()) { entry in
            ReadingStatsEntryView(entry: entry)
        }
        .configurationDisplayName("阅读统计")
        .description("显示今日阅读时长和字数")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

struct ReadingStatsEntry: TimelineEntry {
    let date: Date
    let todayMinutes: Int
    let todayWords: Int
    let totalMinutes: Int
    let streakDays: Int
    let goalMinutes: Int
}

struct ReadingStatsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingStatsEntry {
        ReadingStatsEntry(date: Date(), todayMinutes: 45, todayWords: 12000, totalMinutes: 3600, streakDays: 7, goalMinutes: 60)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingStatsEntry) -> Void) {
        completion(loadStats())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingStatsEntry>) -> Void) {
        let entry = loadStats()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func loadStats() -> ReadingStatsEntry {
        let defaults = UserDefaults(suiteName: "group.com.chrn11.legado")
        return ReadingStatsEntry(
            date: Date(),
            todayMinutes: defaults?.integer(forKey: "widget_todayMinutes") ?? 0,
            todayWords: defaults?.integer(forKey: "widget_todayWords") ?? 0,
            totalMinutes: defaults?.integer(forKey: "widget_totalMinutes") ?? 0,
            streakDays: defaults?.integer(forKey: "widget_streakDays") ?? 0,
            goalMinutes: defaults?.integer(forKey: "widget_goalMinutes") ?? 60
        )
    }
}

struct ReadingStatsEntryView: View {
    let entry: ReadingStatsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("今日阅读")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(formatMinutes(entry.todayMinutes))
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(entry.todayWords) 字")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if entry.goalMinutes > 0 {
                    let goalProgress = min(Double(entry.todayMinutes) / Double(entry.goalMinutes), 1.0)
                    ProgressView(value: goalProgress)
                        .progressViewStyle(.linear)
                        .tint(goalProgress >= 1.0 ? .green : .blue)
                    Text(goalProgress >= 1.0 ? "目标达成!" : "目标 \(entry.goalMinutes)分钟")
                        .font(.caption2)
                        .foregroundColor(goalProgress >= 1.0 ? .green : .secondary)
                }
            }
            .padding()
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }

        case .systemMedium:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("今日阅读")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(formatMinutes(entry.todayMinutes))
                        .font(.title)
                        .fontWeight(.bold)

                    Text("\(entry.todayWords) 字")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 8) {
                    if entry.goalMinutes > 0 {
                        let goalProgress = min(Double(entry.todayMinutes) / Double(entry.goalMinutes), 1.0)
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                            Circle()
                                .trim(from: 0, to: goalProgress)
                                .stroke(goalProgress >= 1.0 ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(goalProgress * 100))%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .frame(width: 50, height: 50)
                    }

                    if entry.streakDays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(entry.streakDays)天")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if entry.goalMinutes > 0 {
                    let goalProgress = min(Double(entry.todayMinutes) / Double(entry.goalMinutes), 1.0)
                    ProgressView(value: goalProgress)
                        .progressViewStyle(.circular)
                        .tint(goalProgress >= 1.0 ? .green : .blue)
                }
                Text("\(entry.todayMinutes)m")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .containerBackground(for: .widget) {
                Color.clear
            }

        default:
            Text("阅读统计")
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - 书架更新小组件

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
        let hasUpdate: Bool
    }
}

struct BookshelfTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BookshelfEntry {
        BookshelfEntry(date: Date(), books: [
            .init(name: "示例书籍1", latestChapter: "第100章", hasUpdate: true),
            .init(name: "示例书籍2", latestChapter: "第50章", hasUpdate: false),
            .init(name: "示例书籍3", latestChapter: "第200章", hasUpdate: true),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (BookshelfEntry) -> Void) {
        completion(loadBooks())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BookshelfEntry>) -> Void) {
        let entry = loadBooks()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadBooks() -> BookshelfEntry {
        let defaults = UserDefaults(suiteName: "group.com.chrn11.legado")
        var books: [BookshelfEntry.BookInfo] = []

        if let names = defaults?.stringArray(forKey: "widget_bookNames"),
           let chapters = defaults?.stringArray(forKey: "widget_latestChapters"),
           let updates = defaults?.stringArray(forKey: "widget_hasUpdates") {
            for i in 0..<min(names.count, chapters.count) {
                let hasUpdate = i < updates.count ? updates[i] == "1" : false
                books.append(.init(name: names[i], latestChapter: chapters[i], hasUpdate: hasUpdate))
            }
        }

        return BookshelfEntry(date: Date(), books: books.isEmpty ? placeholder(in: Context()).books : books)
    }
}

struct BookshelfEntryView: View {
    let entry: BookshelfEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "books.vertical.fill")
                    .foregroundColor(.blue)
                Text("书架更新")
                    .font(.headline)
                Spacer()
                let updateCount = entry.books.filter { $0.hasUpdate }.count
                if updateCount > 0 {
                    Text("\(updateCount)本更新")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }

            let maxBooks = family == .systemMedium ? 3 : 6
            ForEach(entry.books.prefix(maxBooks), id: \.name) { book in
                HStack(spacing: 8) {
                    Image(systemName: book.hasUpdate ? "book.fill" : "book")
                        .foregroundColor(book.hasUpdate ? .blue : .gray)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(book.name)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        Text(book.latestChapter)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if book.hasUpdate {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget Bundle

@main
struct LegadoWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReadingProgressWidget()
        ReadingStatsWidget()
        BookshelfWidget()
    }
}

// MARK: - Widget 数据同步工具

struct WidgetDataSync {
    static let shared = WidgetDataSync()
    private let defaults = UserDefaults(suiteName: "group.com.chrn11.legado")

    func syncReadingProgress(book: Book) {
        defaults?.set(book.name, forKey: "widget_bookName")
        defaults?.set(book.author, forKey: "widget_author")
        defaults?.set(book.durChapterTitle ?? "", forKey: "widget_chapterTitle")
        let progress = book.totalChapterNum > 0
            ? Double(book.durChapterIndex) / Double(book.totalChapterNum)
            : 0
        defaults?.set(progress, forKey: "widget_progress")
        defaults?.set(Int(book.totalChapterNum), forKey: "widget_totalChapters")
        defaults?.set(Int(book.durChapterIndex), forKey: "widget_currentChapter")
        WidgetCenter.shared.reloadTimelines(ofKind: "ReadingProgress")
    }

    func syncReadingStats(todayMinutes: Int, todayWords: Int, totalMinutes: Int, streakDays: Int, goalMinutes: Int = 60) {
        defaults?.set(todayMinutes, forKey: "widget_todayMinutes")
        defaults?.set(todayWords, forKey: "widget_todayWords")
        defaults?.set(totalMinutes, forKey: "widget_totalMinutes")
        defaults?.set(streakDays, forKey: "widget_streakDays")
        defaults?.set(goalMinutes, forKey: "widget_goalMinutes")
        WidgetCenter.shared.reloadTimelines(ofKind: "ReadingStats")
    }

    func syncBookshelfUpdates(books: [(name: String, latestChapter: String, hasUpdate: Bool)]) {
        defaults?.set(books.map { $0.name }, forKey: "widget_bookNames")
        defaults?.set(books.map { $0.latestChapter }, forKey: "widget_latestChapters")
        defaults?.set(books.map { $0.hasUpdate ? "1" : "0" }, forKey: "widget_hasUpdates")
        WidgetCenter.shared.reloadTimelines(ofKind: "Bookshelf")
    }

    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
