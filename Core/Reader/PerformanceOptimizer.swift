import Foundation

class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()
    
    private var preloadedChapters: [Int: TextChapter] = [:]
    private var preloadQueue: DispatchQueue
    private var maxPreloadCount: Int = 3
    
    private init() {
        preloadQueue = DispatchQueue(label: "com.legado.preload", qos: .utility)
    }
    
    func preloadChapters(book: Book, currentIndex: Int, chapters: [BookChapter]) {
        preloadQueue.async {
            let preloadRange = self.calculatePreloadRange(currentIndex: currentIndex, total: chapters.count)
            
            for index in preloadRange {
                if self.preloadedChapters[index] == nil {
                    self.preloadChapter(book: book, chapter: chapters[index], index: index)
                }
            }
            
            self.cleanupOldPreloads(currentIndex: currentIndex)
        }
    }
    
    private func calculatePreloadRange(currentIndex: Int, total: Int) -> Range<Int> {
        let start = max(0, currentIndex - 1)
        let end = min(total, currentIndex + maxPreloadCount + 1)
        return start..<end
    }
    
    private func preloadChapter(book: Book, chapter: BookChapter, index: Int) {
        autoreleasepool {
            do {
                let textChapter = try self.loadChapterSync(book: book, chapter: chapter)
                DispatchQueue.main.async {
                    self.preloadedChapters[index] = textChapter
                }
            } catch {
            }
        }
    }
    
    private func loadChapterSync(book: Book, chapter: BookChapter) throws -> TextChapter {
        let context = CoreDataStack.shared.newBackgroundContext()
        
        return context.performAndWait {
            let textChapter = TextChapter(
                chapter: chapter,
                position: Int(chapter.index),
                title: chapter.title,
                chaptersSize: book.totalChapterNum,
                sameTitleRemoved: false,
                isVip: chapter.isVIP,
                isPay: false,
                effectiveReplaceRules: nil
            )
            return textChapter
        }
    }
    
    private func cleanupOldPreloads(currentIndex: Int) {
        let indicesToRemove = preloadedChapters.keys.filter { abs($0 - currentIndex) > maxPreloadCount + 2 }
        
        DispatchQueue.main.async {
            for index in indicesToRemove {
                self.preloadedChapters.removeValue(forKey: index)
            }
        }
    }
    
    func getPreloadedChapter(index: Int) -> TextChapter? {
        return preloadedChapters[index]
    }
    
    func clearPreloads() {
        preloadedChapters.removeAll()
    }
    
    func optimizeMemory() {
        autoreleasepool {
            clearPreloads()
        }
    }
}

class AsyncLayoutManager {
    private var layoutQueue: DispatchQueue
    private var activeLayouts: [Int: Task<Void, Never>] = [:]
    
    init() {
        layoutQueue = DispatchQueue(label: "com.legado.layout", qos: .userInitiated)
    }
    
    func layoutChapterAsync(
        textChapter: TextChapter,
        book: Book,
        bookContent: BookContent,
        completion: @escaping (TextChapter) -> Void
    ) {
        let index = textChapter.position
        
        if let existingTask = activeLayouts[index] {
            existingTask.cancel()
        }
        
        let task = Task {
            do {
                let layout = TextChapterLayout(
                    textChapter: textChapter,
                    textPages: [],
                    book: book,
                    bookContent: bookContent
                )
                
                await layout.startLayout()
                
                if !Task.isCancelled {
                    await MainActor.run {
                        completion(textChapter)
                    }
                }
                
                activeLayouts.removeValue(forKey: index)
            } catch {
                activeLayouts.removeValue(forKey: index)
            }
        }
        
        activeLayouts[index] = task
    }
    
    func cancelLayout(index: Int) {
        if let task = activeLayouts[index] {
            task.cancel()
            activeLayouts.removeValue(forKey: index)
        }
    }
    
    func cancelAllLayouts() {
        for (_, task) in activeLayouts {
            task.cancel()
        }
        activeLayouts.removeAll()
    }
}

class CacheOptimizer {
    static let shared = CacheOptimizer()
    
    private let maxCacheSize: Int64 = 100 * 1024 * 1024
    private var currentCacheSize: Int64 = 0
    
    func optimizeChapterCache() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDir = documents.appendingPathComponent("chapters")
        
        guard FileManager.default.fileExists(atPath: cacheDir.path) else { return }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
            
            var totalSize: Int64 = 0
            var fileInfos: [(URL, Int64, Date)] = []
            
            for file in files {
                let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
                let size = (attrs[.size] as? Int64) ?? 0
                let modDate = (attrs[.modificationDate] as? Date) ?? Date.distantPast
                totalSize += size
                fileInfos.append((file, size, modDate))
            }
            
            if totalSize > maxCacheSize {
                fileInfos.sort { $0.2 < $1.2 }
                
                var deletedSize: Int64 = 0
                for (file, size, _) in fileInfos {
                    if totalSize - deletedSize <= maxCacheSize {
                        break
                    }
                    try FileManager.default.removeItem(at: file)
                    deletedSize += size
                }
            }
            
            currentCacheSize = totalSize
        } catch {
        }
    }
    
    func getCacheSize() -> Int64 {
        return currentCacheSize
    }
    
    func clearAllCache() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDir = documents.appendingPathComponent("chapters")
        
        if FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.removeItem(at: cacheDir)
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        currentCacheSize = 0
    }
}