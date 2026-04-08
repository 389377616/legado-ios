import SwiftUI
import CoreData

struct RssSortView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sources: [RssSource] = []
    @State private var showDeleteConfirm = false
    @State private var sourceToDelete: RssSource?
    
    var body: some View {
        List {
            if sources.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("暂无RSS源")
                        .font(.headline)
                    Text("请先添加RSS源")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(sources, id: \.sourceId) { source in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.sourceName)
                                .font(.headline)
                            Text(source.sourceUrl)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if !source.enabled {
                            Text("已禁用")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSource(source)
                    }
                }
                .onDelete(perform: deleteSources)
                .onMove(perform: moveSource)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("RSS源排序")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("完成") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .task {
            loadSources()
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let source = sourceToDelete {
                    deleteSource(source)
                }
            }
        } message: {
            Text("确定要删除 \"\(sourceToDelete?.sourceName ?? "")\" 吗？")
        }
    }
    
    private func loadSources() {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<RssSource> = RssSource.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "customOrder", ascending: true)]
        sources = (try? context.fetch(request)) ?? []
    }
    
    private func toggleSource(_ source: RssSource) {
        source.enabled.toggle()
        try? CoreDataStack.shared.save()
        loadSources()
    }
    
    private func moveSource(from source: IndexSet, to destination: Int) {
        var reordered = sources
        reordered.move(fromOffsets: source, toOffset: destination)
        
        for (index, source) in reordered.enumerated() {
            source.customOrder = Int32(index)
        }
        
        try? CoreDataStack.shared.save()
        loadSources()
    }
    
    private func deleteSources(at offsets: IndexSet) {
        let context = CoreDataStack.shared.viewContext
        for index in offsets {
            context.delete(sources[index])
        }
        try? CoreDataStack.shared.save()
        loadSources()
    }
    
    private func deleteSource(_ source: RssSource) {
        let context = CoreDataStack.shared.viewContext
        context.delete(source)
        try? CoreDataStack.shared.save()
        loadSources()
    }
}