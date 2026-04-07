//
//  WelcomeView.swift
//  Legado-iOS
//
//  欢迎页面 - 首次启动引导
//

import SwiftUI

struct WelcomeView: View {
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @State private var currentPage = 0
    
    private let pages: [WelcomePage] = [
        WelcomePage(
            icon: "books.vertical.fill",
            title: "欢迎使用 Legado",
            subtitle: "一款开源、免费的阅读应用",
            description: "Legado 是一款高度可定制的阅读应用，支持自定义书源规则，让你轻松获取网络文学内容。"
        ),
        WelcomePage(
            icon: "network",
            title: "书源规则",
            subtitle: "自由订阅，无限可能",
            description: "支持自定义书源规则，可以解析各大网站内容。你可以导入他人分享的书源，也可以自己编写规则。"
        ),
        WelcomePage(
            icon: "text.book.closed.fill",
            title: "本地阅读",
            subtitle: "支持多种格式",
            description: "支持本地 TXT、EPUB 文件导入，随时随地阅读你喜爱的书籍。"
        ),
        WelcomePage(
            icon: "slider.horizontal.3",
            title: "个性定制",
            subtitle: "打造专属阅读体验",
            description: "多种翻页模式、字体设置、主题配色，打造最舒适的阅读环境。"
        ),
        WelcomePage(
            icon: "arrow.down.circle.fill",
            title: "开始使用",
            subtitle: "准备就绪",
            description: "现在就导入书源，开始你的阅读之旅吧！"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    WelcomePageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            
            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    Button(action: completeWelcome) {
                        Text("开始使用")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                } else {
                    Button(action: { withAnimation { currentPage += 1 } }) {
                        Text("下一步")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    
                    Button(action: completeWelcome) {
                        Text("跳过")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
    
    private func completeWelcome() {
        hasCompletedWelcome = true
    }
}

struct WelcomePage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
}

struct WelcomePageView: View {
    let page: WelcomePage
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(page.subtitle)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

#Preview {
    WelcomeView()
}