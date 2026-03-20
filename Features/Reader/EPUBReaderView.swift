import SwiftUI
import WebKit

struct EPUBReaderView: UIViewRepresentable {
    let htmlURL: URL
    let baseURL: URL
    let onTap: (() -> Void)?
    let onSwipeLeft: (() -> Void)?
    let onSwipeRight: (() -> Void)?
    
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
        tapGesture.delegate = context.coordinator
        webView.addGestureRecognizer(tapGesture)
        
        let leftSwipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        leftSwipe.direction = .left
        leftSwipe.delegate = context.coordinator
        webView.addGestureRecognizer(leftSwipe)
        
        let rightSwipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        rightSwipe.direction = .right
        rightSwipe.delegate = context.coordinator
        webView.addGestureRecognizer(rightSwipe)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != htmlURL {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseURL)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIGestureRecognizerDelegate {
        let onTap: (() -> Void)?
        let onSwipeLeft: (() -> Void)?
        let onSwipeRight: (() -> Void)?
        
        init(onTap: (() -> Void)?, onSwipeLeft: (() -> Void)?, onSwipeRight: (() -> Void)?) {
            self.onTap = onTap
            self.onSwipeLeft = onSwipeLeft
            self.onSwipeRight = onSwipeRight
        }
        
        @objc func handleTap() {
            onTap?()
        }
        
        @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
            if gesture.direction == .left {
                onSwipeLeft?()
            } else if gesture.direction == .right {
                onSwipeRight?()
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}