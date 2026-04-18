import SwiftUI
import WebKit

struct HTMLContentView: UIViewRepresentable {
    let htmlContent: String
    let htmlURL: URL?
    let baseURL: URL?
    let fontSize: CGFloat
    let textColor: Color
    let backgroundColor: Color
    let imageStyle: ImageStyle
    let preserveOriginalStyles: Bool
    let onTap: (() -> Void)?
    
    init(
        htmlContent: String,
        htmlURL: URL? = nil,
        baseURL: URL? = nil,
        fontSize: CGFloat = 18,
        textColor: Color = .black,
        backgroundColor: Color = .white,
        imageStyle: ImageStyle = .full,
        preserveOriginalStyles: Bool = true,
        onTap: (() -> Void)? = nil
    ) {
        self.htmlContent = htmlContent
        self.htmlURL = htmlURL
        self.baseURL = baseURL
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.imageStyle = imageStyle
        self.preserveOriginalStyles = preserveOriginalStyles
        self.onTap = onTap
    }
    
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
        context.coordinator.fontSize = fontSize
        context.coordinator.textColor = textColor
        context.coordinator.backgroundColor = backgroundColor
        context.coordinator.preserveOriginalStyles = preserveOriginalStyles
        
        if let htmlURL = htmlURL, let baseURL = baseURL {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseURL)
        } else {
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
            webView.loadHTMLString(wrappedHTML, baseURL: baseURL)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTap: onTap,
            fontSize: fontSize,
            textColor: textColor,
            backgroundColor: backgroundColor,
            preserveOriginalStyles: preserveOriginalStyles
        )
    }
    
    private func generateCSS() -> String {
        let textColorHex = UIColor(textColor).hexString
        let bgColorHex = UIColor(backgroundColor).hexString
        
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
        img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 16px auto;
        }
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIGestureRecognizerDelegate {
        var onTap: (() -> Void)?
        var fontSize: CGFloat
        var textColor: Color
        var backgroundColor: Color
        var preserveOriginalStyles: Bool
        
        init(
            onTap: (() -> Void)?,
            fontSize: CGFloat,
            textColor: Color,
            backgroundColor: Color,
            preserveOriginalStyles: Bool
        ) {
            self.onTap = onTap
            self.fontSize = fontSize
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.preserveOriginalStyles = preserveOriginalStyles
        }
        
        @objc func handleTap() {
            onTap?()
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if preserveOriginalStyles {
                return
            }
            
            let textColorHex = UIColor(textColor).hexString
            let bgColorHex = UIColor(backgroundColor).hexString
            
            let js = """
            (function() {
                var style = document.createElement('style');
                style.innerHTML = `
                    html, body { background-color: \(bgColorHex); color: \(textColorHex); }
                    body { font-size: \(fontSize)px; }
                    img { max-width: 100%; height: auto; }
                `;
                document.head.appendChild(style);
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
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