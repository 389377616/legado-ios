import SwiftUI
import WebKit

struct RssReadView: View {
    let articleLink: String
    let articleTitle: String
    let articleOrigin: String
    
    @State private var isLoading = true
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
            }
            
            RssWebView(url: articleLink, isLoading: $isLoading, progress: $progress)
        }
        .navigationTitle(articleTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: openInSafari) {
                    Image(systemName: "safari")
                }
                Button(action: shareArticle) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
    
    private func openInSafari() {
        guard let url = URL(string: articleLink) else { return }
        UIApplication.shared.open(url)
    }
    
    private func shareArticle() {
        guard let url = URL(string: articleLink) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct RssWebView: UIViewRepresentable {
    let url: String
    @Binding var isLoading: Bool
    @Binding var progress: Double
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url?.absoluteString != url, let requestURL = URL(string: url) {
            webView.load(URLRequest(url: requestURL))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, progress: $progress)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var progress: Double
        
        init(isLoading: Binding<Bool>, progress: Binding<Double>) {
            _isLoading = isLoading
            _progress = progress
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            progress = 1.0
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}