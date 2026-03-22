import SwiftUI
import CoreData

struct DiscoveryView: View {
    @StateObject private var viewModel = DiscoveryViewModel()
    @State private var searchText = ""
    @State private var selectedGroup: String?
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            if viewModel.exploreGroups.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                exploreList
            }
        }
        .navigationTitle("发现")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadExploreGroups() }
        .refreshable { await viewModel.refresh() }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索书源", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _ in
                    viewModel.filterGroups(keyword: searchText)
                }
            
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
            Image(systemName: "books.vertical")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无发现内容")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("请确保已添加支持发现功能的书源")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var exploreList: some View {
        List {
            ForEach(viewModel.filteredGroups, id: \.sourceId) { group in
                ExploreGroupRow(group: group) {
                    viewModel.toggleGroup(group.sourceId)
                }
                
                if viewModel.isExpanded(group.sourceId) {
                    ForEach(group.exploreKinds, id: \.title) { kind in
                        Button(action: {
                            viewModel.openExplore(group: group, kind: kind)
                        }) {
                            HStack {
                                Text(kind.title)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct ExploreGroupRow: View {
    let group: ExploreGroup
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(group.sourceName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if group.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(group.isExpanded ? 90 : 0))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ExploreKind: Identifiable {
    let id = UUID()
    let title: String
    let url: String
}

struct ExploreGroup: Identifiable {
    let id = UUID()
    let sourceId: UUID
    let sourceName: String
    var exploreKinds: [ExploreKind] = []
    var isLoading = false
    var isExpanded = false
}

@MainActor
class DiscoveryViewModel: ObservableObject {
    @Published var exploreGroups: [ExploreGroup] = []
    @Published var filteredGroups: [ExploreGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var expandedGroups: Set<UUID> = []
    
    func loadExploreGroups() async {
        isLoading = true
        
        let context = CoreDataStack.shared.viewContext
        let request = BookSource.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == YES AND enabledExplore == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "bookSourceName", ascending: true)]
        
        if let sources = try? context.fetch(request) {
            exploreGroups = sources.compactMap { source in
                guard let sourceId = source.sourceId else { return nil }
                var group = ExploreGroup(sourceId: sourceId, sourceName: source.bookSourceName)
                
                if let exploreUrl = source.exploreUrl, !exploreUrl.isEmpty {
                    group.exploreKinds = parseExploreUrl(exploreUrl)
                }
                
                return group
            }
            filteredGroups = exploreGroups
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadExploreGroups()
    }
    
    func filterGroups(keyword: String) {
        if keyword.isEmpty {
            filteredGroups = exploreGroups
        } else {
            filteredGroups = exploreGroups.filter {
                $0.sourceName.localizedCaseInsensitiveContains(keyword)
            }
        }
    }
    
    func toggleGroup(_ sourceId: UUID) {
        if let index = exploreGroups.firstIndex(where: { $0.sourceId == sourceId }) {
            exploreGroups[index].isExpanded.toggle()
            expandedGroups.insert(sourceId)
            filteredGroups = exploreGroups
        }
    }
    
    func isExpanded(_ sourceId: UUID) -> Bool {
        exploreGroups.first { $0.sourceId == sourceId }?.isExpanded ?? false
    }
    
    func openExplore(group: ExploreGroup, kind: ExploreKind) {
        // TODO: 导航到发现详情页
    }
    
    private func parseExploreUrl(_ exploreUrl: String) -> [ExploreKind] {
        var kinds: [ExploreKind] = []
        
        let items = exploreUrl.components(separatedBy: "&&")
        for item in items {
            let parts = item.components(separatedBy: "::")
            if parts.count >= 2 {
                kinds.append(ExploreKind(title: parts[0].trimmingCharacters(in: .whitespaces), url: parts[1].trimmingCharacters(in: .whitespaces)))
            } else if parts.count == 1 {
                let trimmed = parts[0].trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    kinds.append(ExploreKind(title: trimmed, url: trimmed))
                }
            }
        }
        
        return kinds
    }
}

#Preview {
    NavigationStack {
        DiscoveryView()
    }
}