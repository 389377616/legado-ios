import SwiftUI
import CoreData

struct RSSSubscriptionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "sortOrder", ascending: true)],
        animation: .default
    ) private var sources: FetchedResults<RssSource>
    
    @State private var searchText = ""
    @State private var showingAddSource = false
    @State private var selectedSource: RssSource?
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            if filteredSources.isEmpty {
                emptyView
            } else {
                sourceGrid
            }
        }
        .navigationTitle("RSS")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSource) { source in
            RSSArticlesView(source: source)
        }
        .sheet(isPresented: $showingAddSource) {
            AddRSSSourceView()
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索订阅源", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无订阅源")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击右上角 + 添加订阅源")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var sourceGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredSources, id: \.sourceId) { source in
                    RSSSourceItem(source: source) {
                        selectedSource = source
                    }
                }
            }
            .padding()
        }
    }
    
    private var filteredSources: [RssSource] {
        if searchText.isEmpty {
            return Array(sources)
        }
        return sources.filter {
            $0.sourceName?.localizedCaseInsensitiveContains(searchText) ?? false ||
            $0.sourceUrl?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
}

struct RSSSourceItem: View {
    let source: RssSource
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                AsyncImage(url: source.iconUrl.flatMap { URL(string: $0) }) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        ZStack {
                            Color(.systemGray5)
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(source.sourceName ?? "未知")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }
}

struct RSSArticlesView: View {
    let source: RssSource
    @Environment(\.dismiss) private var dismiss
    @State private var articles: [RSSArticle] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                } else if articles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("暂无文章")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(articles) { article in
                        Link(destination: URL(string: article.link) ?? URL(string: "about:blank")!) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                
                                if let desc = article.description, !desc.isEmpty {
                                    Text(desc.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                if let date = article.pubDate {
                                    Text(date.formatted(.relative(presentation: .named)))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(source.sourceName ?? "RSS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await loadArticles() }
        }
    }
    
    private func loadArticles() async {
        guard let url = source.sourceUrl else { return }
        
        do {
            let (_, items) = try await RSSParser.fetchAndParse(url: url)
            articles = items
        } catch {
            print("RSS load error: \(error)")
        }
        
        isLoading = false
    }
}

struct AddRSSSourceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var name = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("订阅地址") {
                    TextField("RSS/Atom 链接", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section("名称（可选）") {
                    TextField("自定义名称", text: $name)
                }
            }
            .navigationTitle("添加订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { addSource() }
                        .disabled(url.isEmpty)
                }
            }
        }
    }
    
    private func addSource() {
        let context = CoreDataStack.shared.viewContext
        let source = RssSource.create(in: context)
        source.sourceUrl = url
        source.sourceName = name.isEmpty ? url : name
        try? context.save()
        dismiss()
    }
}

struct RSSArticle: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    let description: String?
    let pubDate: Date?
    let author: String?
}

class RSSParser {
    static func parse(xmlData: Data, sourceUrl: String) -> [RSSArticle] {
        let parser = XMLFeedParser(data: xmlData, sourceUrl: sourceUrl)
        parser.parse()
        return parser.articles
    }
    
    static func fetchAndParse(url: String) async throws -> (String, [RSSArticle]) {
        guard let feedUrl = URL(string: url) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: feedUrl)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let parser = XMLFeedParser(data: data, sourceUrl: url)
        parser.parse()
        
        return (parser.feedTitle ?? "未知订阅", parser.articles)
    }
}

private class XMLFeedParser: NSObject, XMLParserDelegate {
    private let sourceUrl: String
    var feedTitle: String?
    var articles: [RSSArticle] = []
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var isInItem = false
    
    init(data: Data, sourceUrl: String) {
        self.sourceUrl = sourceUrl
    }
    
    func parse() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: sourceUrl)) else { return }
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" || elementName == "entry" {
            isInItem = true
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "link": currentLink += string
        case "description", "summary": currentDescription += string
        case "pubDate", "published": currentPubDate += string
        default: break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            let article = RSSArticle(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: parseDate(currentPubDate),
                author: nil
            )
            articles.append(article)
            
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
            isInItem = false
        }
    }
    
    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter.date(from: string)
    }
}

#Preview {
    NavigationStack {
        RSSSubscriptionView()
    }
}