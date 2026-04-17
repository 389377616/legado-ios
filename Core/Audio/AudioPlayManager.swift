import Foundation
import AVFoundation
import MediaPlayer
import CoreData

@MainActor
class AudioPlayManager: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentChapterIndex: Int = 0
    @Published var totalChapters: Int = 0
    @Published var playbackRate: Float = 1.0
    @Published var currentBook: Book?
    @Published var currentChapter: BookChapter?
    @Published var chapters: [BookChapter] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var ruleEngine = RuleEngine()
    
    init() {
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: .allowBluetooth)
            try session.setActive(true)
        } catch {
            print("音频会话配置失败: \(error)")
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in await self?.nextChapter() }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in await self?.prevChapter() }
            return .success
        }
        
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(by: skipEvent.interval) }
            return .success
        }
        
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(by: -skipEvent.interval) }
            return .success
        }
        
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let rateEvent = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.setPlaybackRate(rateEvent.playbackRate) }
            return .success
        }
    }
    
    func loadBook(_ book: Book) async {
        currentBook = book
        isLoading = true
        errorMessage = nil
        
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        do {
            chapters = try context.fetch(request)
            totalChapters = chapters.count
            
            if book.durChapterIndex < chapters.count {
                currentChapterIndex = Int(book.durChapterIndex)
            }
            
            if let chapter = chapters[safe: currentChapterIndex] {
                await loadChapter(chapter)
            }
        } catch {
            errorMessage = "加载章节失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadChapter(_ chapter: BookChapter) async {
        currentChapter = chapter
        isLoading = true
        
        do {
            let audioURL = try await getAudioURL(for: chapter)
            let playerItem = AVPlayerItem(url: audioURL)
            player = AVPlayer(playerItem: playerItem)
            addTimeObserver()
            updateNowPlayingInfo()
            
            if let book = currentBook, Int(chapter.index) == currentChapterIndex {
                await seekTo(Double(book.durChapterPos))
            }
        } catch {
            errorMessage = "加载音频失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func getAudioURL(for chapter: BookChapter) async throws -> URL {
        if let cachePath = chapter.cachePath,
           FileManager.default.fileExists(atPath: cachePath) {
            return URL(fileURLWithPath: cachePath)
        }
        
        guard let book = currentBook,
              let source = book.source else {
            throw AudioError.noSource
        }
        
        let content = try await WebBook.getContent(
            source: source,
            book: book,
            chapter: chapter
        )
        
        guard let url = URL(string: content) else {
            throw AudioError.invalidAudioURL
        }
        
        if content.hasPrefix("http") {
            return url
        }
        
        throw AudioError.invalidAudioURL
    }
    
    func play() {
        player?.play()
        player?.rate = playbackRate
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        saveProgress()
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }
    
    func stop() {
        player?.pause()
        saveProgress()
        isPlaying = false
        player = nil
    }
    
    func nextChapter() async {
        guard currentChapterIndex < chapters.count - 1 else { return }
        currentChapterIndex += 1
        if let chapter = chapters[safe: currentChapterIndex] {
            await loadChapter(chapter)
            play()
        }
    }
    
    func prevChapter() async {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
        if let chapter = chapters[safe: currentChapterIndex] {
            await loadChapter(chapter)
            play()
        }
    }
    
    func jumpToChapter(_ index: Int) async {
        guard index >= 0, index < chapters.count else { return }
        currentChapterIndex = index
        if let chapter = chapters[safe: index] {
            await loadChapter(chapter)
            play()
        }
    }
    
    func seekTo(_ time: Double) async {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        await player?.seek(to: cmTime)
    }
    
    func seek(by interval: TimeInterval) {
        let newTime = currentTime + interval
        Task {
            await seekTo(max(0, min(duration, newTime)))
        }
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying { player?.rate = rate }
        updateNowPlayingInfo()
    }
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            self.duration = self.player?.currentItem?.duration.seconds ?? 0
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func updateNowPlayingInfo() {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentChapter?.title ?? "未知章节",
            MPMediaItemPropertyArtist: currentBook?.author ?? "未知作者",
            MPMediaItemPropertyAlbumTitle: currentBook?.name ?? "未知书籍",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0,
            MPNowPlayingInfoPropertyCurrentPlaybackDate: Date()
        ]
        nowPlayingInfoCenter.nowPlayingInfo = info
    }
    
    private func saveProgress() {
        guard let book = currentBook else { return }
        let context = CoreDataStack.shared.viewContext
        context.perform {
            book.durChapterIndex = Int32(self.currentChapterIndex)
            book.durChapterPos = Int32(self.currentTime)
            book.durChapterTime = Int64(Date().timeIntervalSince1970)
            book.durChapterTitle = self.currentChapter?.title
            try? context.save()
        }
    }
}

enum AudioError: LocalizedError {
    case noSource
    case invalidAudioURL
    case playbackFailed
    
    var errorDescription: String? {
        switch self {
        case .noSource: return "没有可用的书源"
        case .invalidAudioURL: return "无效的音频地址"
        case .playbackFailed: return "播放失败"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
