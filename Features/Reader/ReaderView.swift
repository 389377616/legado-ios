import SwiftUI
import CoreData

struct ReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReaderViewModel()
    @StateObject private var ttsManager = TTSManager()
    @StateObject private var autoPageTurnManager = AutoPageTurnManager()
    @StateObject private var readingEnhancementManager = ReadingEnhancementManager()
    
    @State private var showingSettings = false
    @State private var showingChapterList = false
    @State private var showingTTSControls = false
    @State private var showingAutoPageTurn = false
    @State private var showingBookmarks = false
    @State private var showingChangeSource = false
    @State private var showingSearchContent = false
    @State private var showUI = true
    @State private var brightness: Double = UIScreen.main.brightness
    @State private var isNightMode = false
    @State private var autoBrightness = true
    
    let bookId: UUID
    
    private var book: Book? {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", bookId as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                viewModel.backgroundColor.ignoresSafeArea()
                
                PagedReaderView(viewModel: viewModel) {
                    autoPageTurnManager.handleTouch()
                    withAnimation { showUI.toggle() }
                }
                
                if showUI {
                    VStack(spacing: 0) {
                        topBar
                            .transition(.move(edge: .top))
                        
                        Spacer()
                        
                        floatingButtons
                            .transition(.opacity)
                        
                        bottomBar
                            .transition(.move(edge: .bottom))
                    }
                    
                    brightnessSlider
                        .transition(.opacity)
                }
                
                if showingSettings {
                    ReaderSettingsView(viewModel: viewModel, isPresented: $showingSettings)
                        .transition(.move(edge: .bottom))
                }
                
                if showingTTSControls {
                    TTSControlsView(ttsManager: ttsManager, viewModel: viewModel, isPresented: $showingTTSControls)
                        .transition(.opacity)
                }
                
                if showingAutoPageTurn {
                    AutoPageTurnControlsView(manager: autoPageTurnManager, isPresented: $showingAutoPageTurn)
                        .transition(.opacity)
                }
                
                AutoPageTurnOverlay(manager: autoPageTurnManager)
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                if let error = viewModel.errorMessage {
                    VStack {
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }
            .onAppear {
                viewModel.loadBook(byId: bookId)
                autoPageTurnManager.onTurnPage = { viewModel.turnToNextPage() }
                autoPageTurnManager.onChapterComplete = {
                    Task { @MainActor in await viewModel.nextChapter() }
                }
                readingEnhancementManager.onNightModeChanged = { isNight in
                    viewModel.applyTheme(isNight ? .dark : .light)
                }
                readingEnhancementManager.startReadingSession()
            }
            .onDisappear {
                viewModel.saveProgress()
                ttsManager.stop()
                autoPageTurnManager.stop()
                readingEnhancementManager.endReadingSession()
            }
            .onChange(of: viewModel.currentPageIndex) { _ in autoPageTurnManager.reset() }
            .alert("阅读提醒", isPresented: Binding(
                get: { readingEnhancementManager.showReminder },
                set: { if !$0 { readingEnhancementManager.dismissReminder() } }
            )) {
                Button("知道了") { readingEnhancementManager.dismissReminder() }
            } message: {
                Text("阅读一段时间了，休息一下眼睛。")
            }
            .sheet(isPresented: $showingChapterList) {
                if let book = book { ChapterListView(viewModel: viewModel, book: book) }
            }
            .sheet(isPresented: $showingChangeSource) {
                if let book = book {
                    ChangeSourceSheet(isPresented: $showingChangeSource, book: book) {
                        viewModel.loadBook(byId: bookId)
                    }
                }
            }
            .sheet(isPresented: $showingBookmarks) {
                if let book = book { BookmarkSheet(viewModel: viewModel, book: book) }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showUI)
    }
    
    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { viewModel.saveProgress(); dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(book?.name ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(viewModel.currentChapter?.title ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: { showingChangeSource = true }) {
                    Text(book?.originName ?? "书源")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }
    
    private var floatingButtons: some View {
        HStack(spacing: 0) {
            Spacer()
            FloatingButton(icon: "magnifyingglass", action: { showingSearchContent = true })
            Spacer()
            FloatingButton(icon: "timer", action: { showingAutoPageTurn = true })
            Spacer()
            FloatingButton(icon: "arrow.3.trianglepath", action: { showingSettings = true })
            Spacer()
            FloatingButton(icon: isNightMode ? "sun.max" : "moon", action: toggleNightMode)
            Spacer()
        }
        .padding(.bottom, 16)
    }
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("第\(viewModel.currentChapterIndex + 1)/\(viewModel.totalChapters)章")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.currentChapter?.title ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Slider(value: Binding(
                    get: { Double(viewModel.currentChapterIndex) },
                    set: { viewModel.jumpToChapter(Int($0)) }
                ), in: 0...Double(max(1, viewModel.totalChapters - 1)), step: 1)
                
                HStack(spacing: 20) {
                    Button(action: { Task { await viewModel.prevChapter() } }) {
                        Text("上一章")
                            .font(.subheadline)
                    }
                    .disabled(viewModel.currentChapterIndex <= 0)
                    .opacity(viewModel.currentChapterIndex <= 0 ? 0.5 : 1)
                    
                    Spacer()
                    
                    Button(action: { Task { await viewModel.nextChapter() } }) {
                        Text("下一章")
                            .font(.subheadline)
                    }
                    .disabled(viewModel.currentChapterIndex >= viewModel.totalChapters - 1)
                    .opacity(viewModel.currentChapterIndex >= viewModel.totalChapters - 1 ? 0.5 : 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 5)
            .padding(.bottom, 5)
            
            Divider()
            
            HStack(spacing: 0) {
                ToolBarButton(icon: "list.bullet", title: "目录", action: { showingChapterList = true })
                ToolBarButton(icon: "speaker.wave.2", title: "朗读", action: { showingTTSControls = true })
                ToolBarButton(icon: "a.square", title: "界面", action: { showingSettings = true })
                ToolBarButton(icon: "gearshape", title: "设置", action: { showingSettings = true })
            }
            .padding(.vertical, 7)
        }
        .background(Color(.systemGray6))
    }
    
    private var brightnessSlider: some View {
        VStack {
            Spacer()
            HStack {
                VStack(spacing: 8) {
                    Button(action: { autoBrightness.toggle() }) {
                        Image(systemName: autoBrightness ? "sun.max.circle.fill" : "sun.max.circle")
                            .font(.title3)
                    }
                    .padding(8)
                    
                    Slider(value: $brightness, in: 0...1)
                        .frame(height: 120)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 30)
                    
                    Image(systemName: "sun.min")
                        .font(.caption)
                        .padding(8)
                }
                .padding(12)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .padding(.leading, 16)
                
                Spacer()
            }
            .padding(.top, 80)
            Spacer()
        }
        .onChange(of: brightness) { newValue in
            if !autoBrightness { UIScreen.main.brightness = newValue }
        }
    }
    
    private func toggleNightMode() {
        isNightMode.toggle()
        viewModel.applyTheme(isNightMode ? .dark : .light)
    }
}

private struct FloatingButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Color(.systemGray5))
                .clipShape(Circle())
        }
    }
}

struct ToolBarButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: 60)
            .foregroundColor(.primary)
        }
    }
}

#Preview { Text("ReaderView Preview") }