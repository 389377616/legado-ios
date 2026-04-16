import SwiftUI

struct iPadAdaptiveReaderView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let onTap: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isiPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var isLandscape: Bool {
        return horizontalSizeClass == .regular && verticalSizeClass == .compact
    }
    
    private var isSplitView: Bool {
        return horizontalSizeClass == .compact && isiPad
    }
    
    var body: some View {
        GeometryReader { geometry in
            if isiPad && isLandscape {
                iPadLandscapeLayout(geometry: geometry)
            } else if isSplitView {
                iPadSplitViewLayout(geometry: geometry)
            } else {
                iPhoneLayout(geometry: geometry)
            }
        }
    }
    
    @ViewBuilder
    private func iPadLandscapeLayout(geometry: GeometryReader.Proxy) -> some View {
        HStack(spacing: 0) {
            VStack {
                ChapterListViewCompact(viewModel: viewModel)
            }
            .frame(width: geometry.size.width * 0.25)
            .background(Color(.systemGray6))
            
            Divider()
            
            ReaderContentArea(viewModel: viewModel, onTap: onTap)
                .frame(width: geometry.size.width * 0.75)
        }
    }
    
    @ViewBuilder
    private func iPadSplitViewLayout(geometry: GeometryReader.Proxy) -> some View {
        ReaderContentArea(viewModel: viewModel, onTap: onTap)
    }
    
    @ViewBuilder
    private func iPhoneLayout(geometry: GeometryReader.Proxy) -> some View {
        ReaderContentArea(viewModel: viewModel, onTap: onTap)
    }
}

struct ReaderContentArea: View {
    @ObservedObject var viewModel: ReaderViewModel
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            viewModel.backgroundColor.ignoresSafeArea()
            
            PagedReaderView(viewModel: viewModel) {
                onTap()
            }
        }
    }
}

struct ChapterListViewCompact: View {
    @ObservedObject var viewModel: ReaderViewModel
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.chapters.indices, id: \.self) { index in
                    Button(action: { viewModel.jumpToChapter(index) }) {
                        HStack {
                            Text(viewModel.chapters[index].title)
                                .font(.system(size: 14))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if index == viewModel.currentChapterIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                            
                            if viewModel.chapters[index].isCached {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct iPadAdaptiveBookshelfView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isiPadLandscape: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }
    
    var body: some View {
        if isiPadLandscape {
            iPadLandscapeBookshelf()
        } else {
            BookshelfView()
        }
    }
}

struct iPadLandscapeBookshelf: View {
    @StateObject private var viewModel = BookshelfViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.groups, id: \.self) { group in
                    Section(header: Text(group.name)) {
                        ForEach(viewModel.booksInGroup(group.id), id: \.bookId) { book in
                            NavigationLink(destination: ReaderView(bookId: book.bookId)) {
                                BookRowCompact(book: book)
                            }
                        }
                    }
                }
            }
            .navigationTitle("书架")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingAddBook = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            
            Text("选择一本书开始阅读")
                .foregroundColor(.secondary)
        }
    }
}

struct BookRowCompact: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            if let cover = book.cover, let uiImage = UIImage(data: cover) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 56)
                    .cornerRadius(4)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .frame(width: 40, height: 56)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                Text(book.author ?? "未知作者")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("第\(book.durChapterIndex + 1)/\(book.totalChapterNum)章")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

extension View {
    func iPadAdaptive() -> some View {
        self.modifier(iPadAdaptiveModifier())
    }
}

struct iPadAdaptiveModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                .padding(horizontalSizeClass == .regular ? 32 : 16)
        } else {
            content
        }
    }
}