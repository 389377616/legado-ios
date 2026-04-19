//
//  EPUBWebPagedView.swift
//  Legado-iOS
//
//  Phase B 精装书 WebView 渲染路径：复用 EPUBReaderView，
//  从 ReaderViewModel 取解析好的 chapterHTMLURL / epubBaseURL，
//  保留 EPUB 原生 CSS/字体/首字下沉/斜体粗体/图片排版。
//
//  手势：
//   - 点击 -> onTap（显示菜单）
//   - 水平滑动 -> 上一章/下一章
//

import SwiftUI

struct EPUBWebPagedView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let onTap: () -> Void

    @AppStorage("reader.delRubyTag") private var delRubyTag: Bool = false
    @AppStorage("reader.delHTag") private var delHTag: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                viewModel.backgroundColor
                    .ignoresSafeArea()

                if let url = viewModel.chapterHTMLURL,
                   let base = viewModel.epubBaseURL {
                    EPUBReaderView(
                        htmlURL: url,
                        baseURL: base,
                        epubBook: nil,
                        onTap: onTap,
                        fontSize: viewModel.fontSize,
                        lineSpacing: viewModel.lineSpacing,
                        textColor: viewModel.textColor,
                        backgroundColor: viewModel.backgroundColor,
                        delRubyTag: delRubyTag,
                        delHTag: delHTag,
                        customCSS: nil
                    )
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                let h = value.translation.width
                                let v = value.translation.height
                                guard abs(h) > abs(v) else { return }
                                if h < -60 {
                                    Task { await viewModel.nextChapter() }
                                } else if h > 60 {
                                    Task { await viewModel.prevChapter() }
                                }
                            }
                    )
                } else if viewModel.isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("精装书章节未就绪")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
