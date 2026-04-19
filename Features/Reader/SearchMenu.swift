//
//  SearchMenu.swift
//  Legado-iOS
//
//  对应 Android view_search_menu.xml
//  作为 ReaderView 的搜索模式下的点击菜单覆盖层
//

import SwiftUI

struct SearchMenu: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Binding var isShown: Bool
    
    let searchResultCount: Int
    let currentSearchIndex: Int
    let currentChapterIndex: Int
    
    let onOpenSearchActivity: () -> Void
    let onExitSearchMenu: () -> Void
    let onShowMenuBar: () -> Void
    let onNavigateToSearch: (_ forward: Bool) -> Void
    let onNavigateChapter: (_ forward: Bool) -> Void
    
    private var primaryText: Color { .primary }
    private var menuBg: some ShapeStyle { .ultraThinMaterial }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissMenu()
                    }
                
                floatingFabs(geo: geo)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    bottomSection
                        .padding(.bottom, geo.safeAreaInsets.bottom)
                        .background(menuBg)
                        .transition(.move(edge: .bottom))
                }
                .ignoresSafeArea(.container, edges: [.bottom])
            }
        }
    }
    
    private func floatingFabs(geo: GeometryProxy) -> some View {
        HStack {
            fabButton(icon: "chevron.left", label: "上一个") {
                onNavigateToSearch(false)
            }
            .padding(.leading, 16)
            
            Spacer()
            
            fabButton(icon: "chevron.right", label: "下一个") {
                onNavigateToSearch(true)
            }
            .padding(.trailing, 16)
        }
        .position(x: geo.size.width / 2, y: geo.size.height / 2)
    }
    
    private func fabButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(primaryText)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color(.systemBackground).opacity(0.95))
                        .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                )
        }
        .accessibilityLabel(label)
    }
    
    private var bottomSection: some View {
        VStack(spacing: 0) {
            searchBaseInfoRow
            
            Divider()
            
            bottomActionRow
        }
    }
    
    private var searchBaseInfoRow: some View {
        HStack {
            Button {
                onNavigateChapter(false)
            } label: {
                Image(systemName: "chevron.up.circle")
                    .font(.system(size: 22))
                    .foregroundColor(primaryText)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Text("搜索结果数: \(searchResultCount) / 当前章节: \(currentChapterIndex + 1)")
                .font(.system(size: 14))
                .foregroundColor(primaryText)
                .lineLimit(1)
            
            Spacer()
            
            Button {
                onNavigateChapter(true)
            } label: {
                Image(systemName: "chevron.down.circle")
                    .font(.system(size: 22))
                    .foregroundColor(primaryText)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private var bottomActionRow: some View {
        HStack {
            Spacer()
            
            bottomButton(icon: "list.bullet.rectangle", title: "结果") {
                onOpenSearchActivity()
            }
            
            Spacer()
            
            bottomButton(icon: "filemenu.and.selection", title: "主菜单") {
                onShowMenuBar()
            }
            
            Spacer()
            
            bottomButton(icon: "xmark.circle", title: "退出") {
                onExitSearchMenu()
                dismissMenu()
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private func bottomButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(height: 24)
                Text(title)
                    .font(.system(size: 12))
            }
            .frame(width: 64)
            .foregroundColor(primaryText)
        }
    }
    
    private func dismissMenu() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isShown = false
        }
    }
}
