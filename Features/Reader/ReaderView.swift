//
//  ReaderView.swift
//  Legado-iOS
//
//  阅读器主界面
//

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
    @State private var showingChangeSource = false
    @State private var showingBookmarks = false
    @State private var showUI = true
    
    let book: Book
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                viewModel.backgroundColor
                    .ignoresSafeArea()
                
                // 内容区域
                PagedReaderView(viewModel: viewModel) {
                    autoPageTurnManager.handleTouch()
                    withAnimation { showUI.toggle() }
                }
                
                // 顶部工具栏
                VStack {
                    HStack {
                        Button(action: {
                            viewModel.saveProgress()
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(book.name)
                                .font(.caption)
                                .lineLimit(1)
                            Text(viewModel.currentChapter?.title ?? "")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button(action: { showingChapterList = true }) {
                            Image(systemName: "list.bullet")
                                .font(.title2)
                        }
                        
                        Button(action: { showingChangeSource = true }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title2)
                        }
                        
                        Button(action: { showingBookmarks = true }) {
                            Image(systemName: "bookmark")
                                .font(.title2)
                        }
                        
                        Button(action: { showingTTSControls = true }) {
                            Image(systemName: "speaker.wave.2")
                                .font(.title2)
                        }
                        
                        Button(action: { showingAutoPageTurn = true }) {
                            Image(systemName: "timer")
                                .font(.title2)
                        }
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "a.square")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.3))
                    .opacity(showUI ? 1.0 : 0.0)
                    .animation(.easeInOut, value: showUI)
                    
                    Spacer()
                    
                    // 底部工具栏
                    VStack(spacing: 8) {
                        // 进度滑块
                        Slider(value: Binding(
                            get: { Double(viewModel.currentChapterIndex) },
                            set: { viewModel.jumpToChapter(Int($0)) }
                        ), in: 0...Double(max(1, viewModel.totalChapters - 1)), step: 1)
                            .padding(.horizontal)
                        
                        HStack {
                            Button(action: { Task { await viewModel.prevChapter() } }) {
                                Label("上一章", systemImage: "chevron.left")
                            }
                            .disabled(viewModel.currentChapterIndex <= 0)
                            
                            Spacer()
                            
                            Text("第\(viewModel.currentChapterIndex + 1)/\(viewModel.totalChapters)章")
                                .font(.caption)
                            
                            Spacer()
                            
                            Button(action: { Task { await viewModel.nextChapter() } }) {
                                Label("下一章", systemImage: "chevron.right")
                            }
                            .disabled(viewModel.currentChapterIndex >= viewModel.totalChapters - 1)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .opacity(showUI ? 1.0 : 0.0)
                    .animation(.easeInOut, value: showUI)
                }
                
                // 设置面板
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
                
                // 加载指示器
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // 错误提示
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
                viewModel.loadBook(book)
                autoPageTurnManager.onTurnPage = { viewModel.turnToNextPage() }
                autoPageTurnManager.onChapterComplete = {
                    Task { @MainActor in
                        await viewModel.nextChapter()
                    }
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
            .onChange(of: viewModel.currentPageIndex) { _ in
                autoPageTurnManager.reset()
            }
            .alert("阅读提醒", isPresented: Binding(
                get: { readingEnhancementManager.showReminder },
                set: { newValue in
                    if !newValue {
                        readingEnhancementManager.dismissReminder()
                    }
                }
            )) {
                Button("知道了") {
                    readingEnhancementManager.dismissReminder()
                }
            } message: {
                Text("阅读一段时间了，休息一下眼睛。")
            }
            .sheet(isPresented: $showingChapterList) {
                ChapterListView(viewModel: viewModel, book: book)
            }
            .sheet(isPresented: $showingChangeSource) {
                ChangeSourceSheet(isPresented: $showingChangeSource, book: book) {
                    viewModel.loadBook(book)
                }
            }
            .sheet(isPresented: $showingBookmarks) {
                BookmarkSheet(viewModel: viewModel, book: book)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showUI)
    }
}

// MARK: - 旧分页视图（保留向后兼容）
struct ReaderPageView: View {
    @ObservedObject var viewModel: ReaderViewModel
    
    var body: some View {
        PagedReaderView(viewModel: viewModel) {
            // 默认无操作
        }
    }
}

#Preview {
    Text("ReaderView Preview")
}