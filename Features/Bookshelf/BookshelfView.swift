//
//  BookshelfView.swift
//  Legado-iOS
//
//  书架主界面
//

import SwiftUI
import CoreData

struct BookshelfView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "durChapterTime", ascending: false)],
        animation: .default
    ) private var fetchedBooks: FetchedResults<Book>
    @StateObject private var viewModel = BookshelfViewModel()
    @StateObject private var localBookViewModel = LocalBookViewModel()
    @State private var showingSourceManage = false
    @State private var showingSearch = false

    var body: some View {
        Group {
            if fetchedBooks.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    EmptyStateView(
                        title: "书架空空如也",
                        subtitle: "点击右上角 + 导入本地书籍",
                        imageName: "books.vertical"
                    )
                    VStack(spacing: 4) {
                        Text(viewModel.coreDataStatus)
                            .font(.caption)
                            .foregroundColor(viewModel.coreDataStatus.contains("❌") ? .red : .secondary)
                        Text(viewModel.debugSummary)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text("显示书籍=\(fetchedBooks.count)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }
            } else {
                bookshelfContent
            }
        }
        .navigationTitle("书架")
        .navigationDestination(for: NSManagedObjectID.self) { objectID in
            readerDestination(for: objectID)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Picker("", selection: $viewModel.viewMode) {
                    Image(systemName: "square.grid.2x2")
                        .tag(BookshelfViewModel.ViewMode.grid)
                    Image(systemName: "list.bullet")
                        .tag(BookshelfViewModel.ViewMode.list)
                }
                .pickerStyle(.segmented)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showingSearch = true }) {
                        Image(systemName: "magnifyingglass")
                    }

                    Button(action: { showingSourceManage = true }) {
                        Image(systemName: "gearshape")
                    }
                    
                    Button(action: {
                        DocumentPickerHelper.shared.present(contentTypes: [.plainText, .text, .utf8PlainText, .data, .epub]) { urls in
                            guard let url = urls.first else { return }
                            Task { @MainActor in
                                do {
                                    try await localBookViewModel.importBook(url: url)
                                    DebugLogger.shared.log("BookshelfView 导入后准备 forceReload")
                                    await viewModel.forceReload()
                                } catch {
                                    localBookViewModel.errorMessage = "导入失败：\(error.localizedDescription)"
                                }
                            }
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSourceManage) {
            SourceManageView()
        }
        .sheet(isPresented: $showingSearch) {
            NavigationStack { SearchResultView() }
        }
        .alert("导入成功", isPresented: Binding(
            get: { localBookViewModel.successMessage != nil },
            set: { isPresented in 
                if !isPresented { 
                    localBookViewModel.successMessage = nil
                    DebugLogger.shared.log("导入成功弹窗关闭，准备 forceReload")
                    Task { 
                        await viewModel.forceReload()
                    }
                }
            }
        )) {
            Button("确定", role: .cancel) { 
                localBookViewModel.successMessage = nil
                DebugLogger.shared.log("导入成功弹窗点击确定，准备 forceReload")
                Task { 
                    await viewModel.forceReload()
                }
            }
        } message: {
            Text(localBookViewModel.successMessage ?? "")
        }
        .alert("导入失败", isPresented: Binding(
            get: { localBookViewModel.errorMessage != nil },
            set: { if !$0 { localBookViewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { localBookViewModel.errorMessage = nil }
        } message: {
            Text(localBookViewModel.errorMessage ?? "未知错误")
        }
        .alert("书架加载失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            DebugLogger.shared.log("BookshelfView.task 触发 loadBooks")
            await viewModel.loadBooks()
        }
        .refreshable {
            await viewModel.refreshBooks()
        }
    }
    
    @ViewBuilder
    private var bookshelfContent: some View {
        switch viewModel.viewMode {
        case .grid:
            bookGridView
        case .list:
            bookListView
        }
    }
    
    private var bookGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(fetchedBooks, id: \.bookId) { book in
                    NavigationLink(value: book.objectID) {
                        BookGridItemView(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    private var bookListView: some View {
        List {
            ForEach(fetchedBooks, id: \.bookId) { book in
                NavigationLink(value: book.objectID) {
                    BookListItemView(book: book)
                }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    viewModel.removeBook(fetchedBooks[index])
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func readerDestination(for objectID: NSManagedObjectID) -> some View {
        if let book = try? viewContext.existingObject(with: objectID) as? Book {
            ReaderView(book: book)
        } else {
            Text("书籍不存在")
                .foregroundColor(.secondary)
        }
    }
}

struct BookGridItemView: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BookCoverView(url: book.coverUrl)
                .frame(maxWidth: .infinity)
                .aspectRatio(3/4, contentMode: .fill)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            Text(book.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Text(book.author)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(.secondary)
            
            ProgressView(value: book.readProgress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
    }
}

struct BookListItemView: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(url: book.coverUrl)
                .frame(width: 60, height: 80)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let chapter = book.latestChapterTitle {
                    Text(chapter)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack {
                    ProgressView(value: book.readProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                    
                    Text("\(Int(book.readProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct BookCoverView: View {
    let url: String?
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "books.vertical")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .task(id: url) {
            guard image == nil, let urlString = url, !urlString.isEmpty else { return }
            image = await ImageCacheManager.shared.loadImage(from: urlString)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let imageName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: imageName)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    BookshelfView()
}
