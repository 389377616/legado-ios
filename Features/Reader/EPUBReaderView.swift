import SwiftUI
import WebKit

struct EPUBReaderView: UIViewRepresentable {
    let htmlURL: URL
    let baseURL: URL
    let onTap: (() -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isTextInteractionEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isPagingEnabled = false
        webView.scrollView.bounces = true
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tapGesture.numberOfTapsRequired = 1
        webView.addGestureRecognizer(tapGesture)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != htmlURL {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseURL)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onTap: (() -> Void)?
        
        init(onTap: (() -> Void)?) {
            self.onTap = onTap
        }
        
        @objc func handleTap() {
            onTap?()
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}