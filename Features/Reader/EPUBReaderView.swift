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
        
        webView.scrollView.isPagingEnabled = true
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceHorizontal = true
        webView.scrollView.alwaysBounceVertical = false
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
            let width = webView.bounds.width
            let height = webView.bounds.height
            let js = """
            (function() {
                var w = \(width);
                var h = \(height);
                var style = document.createElement('style');
                style.innerHTML = `
                    html {
                        height: ` + h + `px;
                        overflow-x: auto;
                        overflow-y: hidden;
                    }
                    body {
                        margin: 0;
                        padding: 0;
                        height: ` + h + `px;
                        -webkit-column-width: ` + w + `px;
                        -webkit-column-gap: 0;
                        -webkit-column-fill: auto;
                        font-size: \(fontSize)px;
                        font-family: -apple-system, sans-serif;
                        line-height: 1.8;
                        text-align: justify;
                    }
                    body > * {
                        display: block;
                        padding: 16px 12px;
                    }
                    img {
                        max-width: 100%;
                        height: auto;
                        display: block;
                        margin: 10px 0;
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