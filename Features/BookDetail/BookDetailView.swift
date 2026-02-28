//
//  BookDetailView.swift
//  Legado-iOS
//
//  书籍详情视图
//

import SwiftUI
import CoreData

struct BookDetailView: View {
    @ObservedObject var viewModel: BookDetailViewModel
    @State private var showingChapterList = false
    @Environment(\.dismiss) var dismiss
    
    let book: Book
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 封面和简介
                HStack(alignment: .top, spacing: 16) {
                    BookCoverView(url: book.displayCoverUrl)
                        .frame(width: 120, height: 160)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(book.author)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if let kind = book.kind {
                            Text(kind)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        if let lastChapter = book.latestChapterTitle {
                            Text("最新：\(lastChapter)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                }
                
                // 简介
                if let intro = book.displayIntro {
                    SectionCard(title: "简介") {
                        Text(intro)
                            .font(.body)
                            .lineSpacing(4)
                    }
                }
                
                // 信息
                SectionCard(title: "信息") {
                    Grid {
                        GridRow {
                            Label("书源", systemImage: "link")
                            Text(book.originName)
                        }
                        
                        GridRow {
                            Label("章节", systemImage: "list.bullet")
                            Text("\(book.totalChapterNum) 章")
                        }
                        
                        GridRow {
                            Label("进度", systemImage: "gauge")
                            Text("\(Int(book.readProgress * 100))%")
                        }
                        
                        if let wordCount = book.wordCount {
                            GridRow {
                                Label("字数", systemImage: "text.alignleft")
                                Text(wordCount)
                            }
                        }
                    }
                    .font(.caption)
                }
                
                // 操作按钮
                HStack(spacing: 16) {
                    Button(action: {
                        // TODO: 开始阅读
                    }) {
                        Label("开始阅读", systemImage: "book.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: showingChapterList = true) {
                        Label("目录", systemImage: "list.bullet")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                // 更新按钮
                Button(action: {
                    Task {
                        await viewModel.updateBook(book)
                    }
                }) {
                    Label("更新书籍信息", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("书籍详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("编辑") {
                        // TODO: 编辑书籍
                    }
                    
                    Button("换源") {
                        // TODO: 换源
                    }
                    
                    Button("删除", role: .destructive) {
                        viewModel.deleteBook(book)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showingChapterList) {
            ChapterListView(viewModel: ReaderViewModel(), book: book)
        }
    }
}

// MARK: - Section Card
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            content
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - ViewModel
class BookDetailViewModel: ObservableObject {
    @Published var isLoading = false
    
    func updateBook(_ book: Book) async {
        isLoading = true
        // TODO: 实现书籍信息更新
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isLoading = false
    }
    
    func deleteBook(_ book: Book) {
        CoreDataStack.shared.viewContext.delete(book)
        try? CoreDataStack.shared.save()
    }
}

#Preview {
    NavigationView {
        BookDetailView(viewModel: BookDetailViewModel(), book: Book())
    }
}
