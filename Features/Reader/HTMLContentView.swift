import SwiftUI
import WebKit

struct HTMLContentView: UIViewRepresentable {
    let htmlContent: String
    let fontSize: CGFloat
    let textColor: Color
    let backgroundColor: Color
    let imageStyle: ImageStyle
    let onTap: (() -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isTextInteractionEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isPagingEnabled = false
        webView.scrollView.bounces = true
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(backgroundColor)
        webView.scrollView.backgroundColor = UIColor(backgroundColor)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = context.coordinator
        webView.addGestureRecognizer(tapGesture)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let css = generateCSS()
        let wrappedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>\(css)</style>
        </head>
        <body>\(htmlContent)</body>
        </html>
        """
        
        webView.loadHTMLString(wrappedHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }
    
    private func generateCSS() -> String {
        let textColorHex = UIColor(textColor).hexString
        let bgColorHex = UIColor(backgroundColor).hexString
        
        let imgStyle: String
        switch imageStyle {
        case .full:
            imgStyle = "width: 100% !important; height: auto !important; object-fit: contain;"
        case .single:
            imgStyle = "max-width: 100%; max-height: 100vh; object-fit: contain; margin: auto;"
        default:
            imgStyle = "max-width: 100%; height: auto;"
        }
        
        return """
        html {
            background-color: \(bgColorHex);
        }
        body {
            margin: 0;
            padding: 20px 16px;
            background-color: \(bgColorHex);
            color: \(textColorHex);
            font-size: \(fontSize)px;
            font-family: -apple-system, sans-serif;
            line-height: 1.8;
            text-align: justify;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        p {
            margin: 0 0 1em 0;
            text-indent: 2em;
        }
        img {
            \(imgStyle)
            display: block;
            margin: 16px auto;
            border-radius: 4px;
        }
        a {
            color: \(textColorHex);
            text-decoration: none;
        }
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIGestureRecognizerDelegate {
        let onTap: (() -> Void)?
        
        init(onTap: (() -> Void)?) {
            self.onTap = onTap
        }
        
        @objc func handleTap() {
            onTap?()
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}