//
//  BookInfoEditView.swift
//  Legado-iOS
//
//  书籍信息编辑
//

import SwiftUI
import CoreData
import PhotosUI
import UIKit

struct BookInfoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BookInfoEditViewModel
    let onSave: () -> Void
    
    init(book: Book, onSave: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: BookInfoEditViewModel(book: book))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("书名", text: $viewModel.name)
                    TextField("作者", text: $viewModel.author)
                    TextField("类型", text: $viewModel.kind)
                }
                
                Section("简介") {
                    TextEditor(text: $viewModel.intro)
                        .frame(minHeight: 100)
                }
                
                Section("封面") {
                    HStack {
                        Group {
                            if let previewImage = viewModel.previewImage {
                                Image(uiImage: previewImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                BookCoverView(url: viewModel.currentCoverURL, sourceId: viewModel.customCoverUrl.isEmpty ? viewModel.sourceId : nil)
                            }
                        }
                        .frame(width: 60, height: 80)
                        .clipped()
                        .cornerRadius(4)

                        TextField("封面URL", text: $viewModel.customCoverUrl)
                    }
                    
                    PhotosPicker(selection: $viewModel.selectedImage, matching: .images) {
                        Label("从相册选择", systemImage: "photo")
                    }
                }
            }
            .navigationTitle("编辑书籍")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel.selectedImage) { _ in
                Task { await viewModel.loadSelectedImage() }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        Task {
                            await viewModel.save()
                            onSave()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

class BookInfoEditViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var author: String = ""
    @Published var kind: String = ""
    @Published var intro: String = ""
    @Published var coverUrl: String = ""
    @Published var customCoverUrl: String = ""
    @Published var selectedImage: PhotosPickerItem?
    @Published var previewImage: UIImage?
    
    private let book: Book
    private let context = CoreDataStack.shared.viewContext
    let sourceId: UUID?

    var currentCoverURL: String {
        customCoverUrl.isEmpty ? coverUrl : customCoverUrl
    }
    
    init(book: Book) {
        self.book = book
        self.sourceId = book.source?.sourceId
        name = book.name
        author = book.author
        kind = book.kind ?? ""
        intro = book.displayIntro ?? ""
        coverUrl = book.coverUrl ?? ""
        customCoverUrl = book.customCoverUrl ?? ""
    }
    
    func loadSelectedImage() async {
        guard let selectedImage,
              let data = try? await selectedImage.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        previewImage = image
        let url = await saveSelectedCoverImage(data)
        if let url {
            customCoverUrl = url.absoluteString
        }
    }

    func save() async {
        book.name = name
        book.author = author
        book.kind = kind.isEmpty ? nil : kind
        book.customIntro = intro.isEmpty ? nil : intro
        book.customCoverUrl = customCoverUrl.isEmpty ? nil : customCoverUrl
        book.updatedAt = Date()
        try? context.save()
    }

    private func saveSelectedCoverImage(_ data: Data) async -> URL? {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let coverDir = documentsPath.appendingPathComponent("covers", isDirectory: true)

        if !fileManager.fileExists(atPath: coverDir.path) {
            try? fileManager.createDirectory(at: coverDir, withIntermediateDirectories: true)
        }

        let coverURL = coverDir.appendingPathComponent("\(book.bookId.uuidString).jpg")
        do {
            try data.write(to: coverURL, options: .atomic)
            return coverURL
        } catch {
            return nil
        }
    }
}
