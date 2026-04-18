//
//  SlidePageView.swift
//  Legado-iOS
//
//  滑动翻页动画：使用 TabView 实现平滑水平滑动
//

import SwiftUI

struct SlidePageView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let pages: [String]
    @Binding var currentPage: Int
    let onTap: () -> Void
    
    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                SinglePageContent(
                    text: page,
                    viewModel: viewModel,
                    onTap: onTap,
                    onTurnPage: { forward in
                        if forward, currentPage + 1 < pages.count {
                            currentPage += 1
                        } else if !forward, currentPage > 0 {
                            currentPage -= 1
                        }
                    }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: currentPage) { newValue in
            viewModel.currentPageIndex = newValue
        }
    }
}

// MARK: - 单页内容

private struct SinglePageContent: View {
    let text: String
    @ObservedObject var viewModel: ReaderViewModel
    let onTap: () -> Void
    let onTurnPage: (Bool) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            ZStack {
                viewModel.backgroundColor
                
                FormattedPageText(
                    text: text,
                    fontSize: viewModel.fontSize,
                    lineSpacing: viewModel.lineSpacing,
                    textColor: viewModel.textColor,
                    paragraphSpacing: viewModel.paragraphSpacing
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(viewModel.pagePadding)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let tapZone = location.x / width
                if tapZone < 0.3 {
                    onTurnPage(false)
                } else if tapZone > 0.7 {
                    onTurnPage(true)
                } else {
                    onTap()
                }
            }
        }
    }
}
