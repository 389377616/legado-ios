import SwiftUI
import WebKit

struct EPUBReaderView: UIViewRepresentable {
    let htmlURL: URL
    let baseURL: URL
    let onTap: (() -> Void)?
    let fontSize: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isTextInteractionEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        webView.paginationMode = .leftToRight
        webView.paginationBreakingMode = .page
        webView.pageLength = 0
        webView.gapBetweenPages = 0
        webView.isPagingEnabled = true
        
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = context.coordinator
        webView.addGestureRecognizer(tapGesture)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != htmlURL {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseURL)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, fontSize: fontSize)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIGestureRecognizerDelegate {
        let onTap: (() -> Void)?
        let fontSize: CGFloat
        
        init(onTap: (() -> Void)?, fontSize: CGFloat) {
            self.onTap = onTap
            self.fontSize = fontSize
        }
        
        @objc func handleTap() {
            onTap?()
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = """
            (function() {
                var style = document.createElement('style');
                style.innerHTML = `
                    html {
                        font-size: \(fontSize)px;
                        -webkit-column-gap: 0;
                    }
                    body {
                        margin: 0;
                        padding: 16px 12px;
                        font-family: -apple-system, sans-serif;
                        line-height: 1.8;
                        text-align: justify;
                    }
                    img {
                        max-width: 100%;
                        height: auto;
                        display: block;
                        margin: 10px auto;
                    }
                    p {
                        margin: 0 0 1em 0;
                        text-indent: 2em;
                    }
                `;
                document.head.appendChild(style);
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}