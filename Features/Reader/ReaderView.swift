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
    @State private var showingEffectiveReplaces = false
    @State private var showUI = false
    @State private var brightness: Double = UIScreen.main.brightness
    @State private var isNightMode = false
    @State private var showingBrightness = false
    
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
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showUI = false; showingBrightness = false }
                        }
                    
                    VStack(spacing: 0) {
                        topBar
                            .padding(.top, geometry.safeAreaInsets.top)
                            .background(.ultraThinMaterial)
                            .transition(.move(edge: .top))
                        
                        Spacer()
                        
                        bottomBar
                            .padding(.bottom, geometry.safeAreaInsets.bottom)
                            .background(.ultraThinMaterial)
                            .transition(.move(edge: .bottom))
                    }
                    .ignoresSafeArea(.container, edges: [.top, .bottom])
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
            .sheet(isPresented: $showingSettings) {
                ReaderSettingsView(viewModel: viewModel, isPresented: $showingSettings)
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
            .sheet(isPresented: $showingTTSControls) {
                TTSControlsView(ttsManager: ttsManager, viewModel: viewModel, isPresented: $showingTTSControls)
            }
            .sheet(isPresented: $showingAutoPageTurn) {
                AutoPageTurnControlsView(manager: autoPageTurnManager, isPresented: $showingAutoPageTurn)
            }
            .sheet(isPresented: $showingEffectiveReplaces) {
                ReplaceRuleView()
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
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
                    HStack(spacing: 4) {
                        Image(systemName: "book.circle")
                            .font(.caption)
                        Text(book?.originName ?? "书源")
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.primary)
                    .cornerRadius(4)
                }
                .frame(maxWidth: 120)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            if let chapter = viewModel.currentChapter, !chapter.title.isEmpty {
                HStack {
                    Text(chapter.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 10)
                    Spacer()
                }
                .padding(.bottom, 4)
            }
        }
    }
    
    private var floatingButtons: some View {
        HStack(spacing: 0) {
            Spacer()
            
            FloatingButton(icon: "magnifyingglass", action: { })
            
            Spacer()
            
            FloatingButton(icon: autoPageTurnManager.isActive ? "play.fill" : "play", action: { showingAutoPageTurn = true })
            
            Spacer()
            
            FloatingButton(icon: "findAndReplace", action: { showingEffectiveReplaces = true })
            
            Spacer()
            
            FloatingButton(icon: isNightMode ? "sun.max.fill" : "moon.fill", action: toggleNightMode)
            
            Spacer()
        }
        .padding(.vertical, 16)
    }
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            floatingButtons
            
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button("上一章") {
                        Task { await viewModel.prevChapter() }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .disabled(viewModel.currentChapterIndex <= 0)
                    
                    Slider(value: Binding(
                        get: { Double(viewModel.currentChapterIndex) },
                        set: { viewModel.jumpToChapter(Int($0)) }
                    ), in: 0...Double(max(1, viewModel.totalChapters - 1)), step: 1)
                    .frame(height: 25)
                    
                    Button("下一章") {
                        Task { await viewModel.nextChapter() }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .disabled(viewModel.currentChapterIndex >= viewModel.totalChapters - 1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 5)
                .padding(.bottom, 5)
                
                HStack(spacing: 0) {
                    Spacer().frame(width: 20)
                    
                    BottomMenuButton(icon: "list.bullet", title: "目录", action: { showingChapterList = true })
                    
                    Spacer().frame(width: 40)
                    
                    BottomMenuButton(icon: "speaker.wave.2", title: "朗读", action: { showingTTSControls = true })
                    
                    Spacer().frame(width: 40)
                    
                    BottomMenuButton(icon: "textformat.size", title: "界面", action: { showingSettings = true })
                    
                    Spacer().frame(width: 40)
                    
                    BottomMenuButton(icon: "gearshape", title: "设置", action: { showingSettings = true })
                    
                    Spacer().frame(width: 20)
                }
                .padding(.bottom, 7)
            }
        }
    }
    
    private func toggleNightMode() {
        isNightMode.toggle()
        viewModel.applyTheme(isNightMode ? .dark : .light)
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

struct FloatingButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

struct BottomMenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(height: 20)
                Text(title)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .frame(width: 60)
            .foregroundColor(.primary)
        }
    }
}

#Preview { Text("ReaderView Preview") }
