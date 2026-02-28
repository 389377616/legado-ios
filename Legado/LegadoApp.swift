//
//  LegadoApp.swift
//  Legado
//
//  Legado iOS - 开源阅读器
//

import SwiftUI
import SwiftData

@main
struct LegadoApp: App {
    // MARK: - SwiftData 容器
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                Book.self,
                BookSource.self,
                Chapter.self,
                Bookmark.self,
                Highlight.self,
                ReadRecord.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
