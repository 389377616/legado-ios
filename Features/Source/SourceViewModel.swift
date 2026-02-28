//
//  SourceViewModel.swift
//  Legado-iOS
//
//  书源管理 ViewModel
//

import Foundation
import CoreData

@MainActor
class SourceViewModel: ObservableObject {
    @Published var sources: [BookSource] = []
    @Published var errorMessage: String?
    
    func loadSources() async {
        do {
            let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "customOrder", ascending: true)]
            
            sources = try CoreDataStack.shared.viewContext.fetch(request)
        } catch {
            errorMessage = "加载书源失败：\(error.localizedDescription)"
        }
    }
    
    func createSource(
        name: String,
        url: String,
        group: String,
        type: Int32,
        searchUrl: String,
        exploreUrl: String
    ) {
        let context = CoreDataStack.shared.viewContext
        let source = BookSource.create(in: context)
        
        source.bookSourceName = name
        source.bookSourceUrl = url
        source.bookSourceGroup = group.isEmpty ? nil : group
        source.bookSourceType = type
        source.searchUrl = searchUrl.isEmpty ? nil : searchUrl
        source.exploreUrl = exploreUrl.isEmpty ? nil : exploreUrl
        
        try? CoreDataStack.shared.save()
        Task {
            await loadSources()
        }
    }
    
    func updateSource(
        _ source: BookSource,
        name: String,
        url: String,
        group: String,
        type: Int32,
        searchUrl: String,
        exploreUrl: String
    ) {
        source.bookSourceName = name
        source.bookSourceUrl = url
        source.bookSourceGroup = group.isEmpty ? nil : group
        source.bookSourceType = type
        source.searchUrl = searchUrl.isEmpty ? nil : searchUrl
        source.exploreUrl = exploreUrl.isEmpty ? nil : exploreUrl
        
        try? CoreDataStack.shared.save()
        Task {
            await loadSources()
        }
    }
    
    func deleteSource(_ source: BookSource) {
        CoreDataStack.shared.viewContext.delete(source)
        try? CoreDataStack.shared.save()
        Task {
            await loadSources()
        }
    }
    
    func deleteSources(at indexSet: IndexSet) {
        for index in indexSet {
            CoreDataStack.shared.viewContext.delete(sources[index])
        }
        try? CoreDataStack.shared.save()
        Task {
            await loadSources()
        }
    }
    
    func importFromURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            errorMessage = "无效的 URL"
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                importFromJSON(json)
            }
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }
    
    func importFromText(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            errorMessage = "无效的文本"
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                importFromJSON(json)
            } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                importSingleSource(json)
            }
        } catch {
            errorMessage = "解析 JSON 失败：\(error.localizedDescription)"
        }
    }
    
    private func importFromJSON(_ sources: [[String: Any]]) {
        let context = CoreDataStack.shared.viewContext
        
        for sourceData in sources {
            let source = BookSource.create(in: context)
            applySourceData(source, sourceData)
        }
        
        try? CoreDataStack.shared.save()
        Task {
            await loadSources()
        }
    }
    
    private func importSingleSource(_ sourceData: [String: Any]) {
        let context = CoreDataStack.shared.viewContext
        let source = BookSource.create(in: context)
        applySourceData(source, sourceData)
        try? CoreDataStack.shared.save()
        Task {
            await loadSources()
        }
    }
    
    private func applySourceData(_ source: BookSource, _ data: [String: Any]) {
        source.bookSourceName = data["bookSourceName"] as? String ?? ""
        source.bookSourceUrl = data["bookSourceUrl"] as? String ?? ""
        source.bookSourceGroup = data["bookSourceGroup"] as? String
        source.bookSourceType = data["bookSourceType"] as? Int32 ?? 0
        source.searchUrl = data["searchUrl"] as? String
        source.exploreUrl = data["exploreUrl"] as? String
        
        // 保存规则 JSON
        if let ruleSearch = data["ruleSearch"] {
            source.ruleSearchData = try? JSONSerialization.data(withJSONObject: ruleSearch)
        }
        if let ruleContent = data["ruleContent"] {
            source.ruleContentData = try? JSONSerialization.data(withJSONObject: ruleContent)
        }
        if let ruleBookInfo = data["ruleBookInfo"] {
            source.ruleBookInfoData = try? JSONSerialization.data(withJSONObject: ruleBookInfo)
        }
        if let ruleToc = data["ruleToc"] {
            source.ruleTocData = try? JSONSerialization.data(withJSONObject: ruleToc)
        }
    }
    
    func exportAllSources() {
        let sources = sources.map { source -> [String: Any] in
            var dict: [String: Any] = [
                "bookSourceName": source.bookSourceName,
                "bookSourceUrl": source.bookSourceUrl
            ]
            
            if let group = source.bookSourceGroup {
                dict["bookSourceGroup"] = group
            }
            
            dict["bookSourceType"] = source.bookSourceType
            dict["searchUrl"] = source.searchUrl
            dict["exploreUrl"] = source.exploreUrl
            
            // 导出规则
            if let searchData = source.ruleSearchData,
               let searchJson = try? JSONSerialization.jsonObject(with: searchData) {
                dict["ruleSearch"] = searchJson
            }
            
            if let contentData = source.ruleContentData,
               let contentJson = try? JSONSerialization.jsonObject(with: contentData) {
                dict["ruleContent"] = contentJson
            }
            
            return dict
        }
        
        // TODO: 导出为文件
        print("导出 \(sources.count) 个书源")
    }
}
