//
//  TextActionMenu.swift
//  Legado-iOS
//
//  文本选择操作菜单 - 参考 Android TextActionMenu
//  长按选中文本后弹出操作菜单
//

import SwiftUI
import UIKit

struct TextActionMenu: View {
    let selectedText: String
    let chapterIndex: Int
    let positionInChapter: Int
    let onCopy: () -> Void
    let onBookmark: () -> Void
    let onSearch: () -> Void
    let onDictionary: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            MenuButton(icon: "doc.on.doc", title: "复制", action: {
                UIPasteboard.general.string = selectedText
                onCopy()
                onDismiss()
            })
            
            Divider()
                .frame(height: 24)
            
            MenuButton(icon: "square.and.arrow.up", title: "分享", action: {
                share(text: selectedText)
                onDismiss()
            })
            
            Divider()
                .frame(height: 24)
            
            MenuButton(icon: "safari", title: "浏览器", action: {
                openInBrowser(text: selectedText)
                onDismiss()
            })
            
            Divider()
                .frame(height: 24)
            
            MenuButton(icon: "bookmark", title: "书签", action: {
                onBookmark()
                onDismiss()
            })
            
            Divider()
                .frame(height: 24)
            
            MenuButton(icon: "magnifyingglass", title: "搜索", action: {
                onSearch()
                onDismiss()
            })
            
            Divider()
                .frame(height: 24)
            
            MenuButton(icon: "book", title: "字典", action: {
                onDictionary()
                onDismiss()
            })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private func share(text: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        var topController = rootVC
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        
        topController.present(activityVC, animated: true)
    }
    
    private func openInBrowser(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedText), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) {
            UIApplication.shared.open(url)
        } else if let encodedText = trimmedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let searchURL = URL(string: "https://www.google.com/search?q=\(encodedText)") {
            UIApplication.shared.open(searchURL)
        }
    }
}

private struct MenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .frame(minWidth: 60)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 字典查询视图

struct DictionaryLookupView: UIViewControllerRepresentable {
    let word: String
    
    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: word)
    }
    
    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}

// MARK: - 文本选择协调器

class TextSelectionCoordinator: ObservableObject {
    @Published var selectedText: String = ""
    @Published var selectionRect: CGRect = .zero
    @Published var showMenu: Bool = false
    @Published var showDictionary: Bool = false
    @Published var dictionaryWord: String = ""
    
    var chapterIndex: Int = 0
    var positionInChapter: Int = 0
    
    func showMenuForSelection(_ text: String, rect: CGRect, chapterIndex: Int, position: Int) {
        self.selectedText = text
        self.selectionRect = rect
        self.chapterIndex = chapterIndex
        self.positionInChapter = position
        self.showMenu = true
    }
    
    func hideMenu() {
        showMenu = false
        selectedText = ""
    }
    
    func showDictionaryForWord(_ word: String) {
        dictionaryWord = word
        showDictionary = true
    }
}