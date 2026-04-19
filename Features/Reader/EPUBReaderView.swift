import SwiftUI
import WebKit

struct EPUBReaderView: UIViewRepresentable {
    let htmlURL: URL
    let baseURL: URL
    let epubBook: EPUBParser.EPUBBook?
    let onTap: (() -> Void)?
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let textColor: Color
    let backgroundColor: Color
    let delRubyTag: Bool
    let delHTag: Bool
    let customCSS: String?
    let preserveBookTypography: Bool

    init(
        htmlURL: URL,
        baseURL: URL,
        epubBook: EPUBParser.EPUBBook? = nil,
        onTap: (() -> Void)? = nil,
        fontSize: CGFloat = 18,
        lineSpacing: CGFloat = 1.8,
        textColor: Color = .black,
        backgroundColor: Color = .white,
        delRubyTag: Bool = false,
        delHTag: Bool = false,
        customCSS: String? = nil,
        preserveBookTypography: Bool = false
    ) {
        self.htmlURL = htmlURL
        self.baseURL = baseURL
        self.epubBook = epubBook
        self.onTap = onTap
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.delRubyTag = delRubyTag
        self.delHTag = delHTag
        self.customCSS = customCSS
        self.preserveBookTypography = preserveBookTypography
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isTextInteractionEnabled = true
        
        if let epubBook = epubBook {
            let handler = EPUBResourceHandler(epubBook: epubBook)
            config.setURLSchemeHandler(handler, forURLScheme: "legado-epub")
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        webView.scrollView.isPagingEnabled = true
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceHorizontal = true
        webView.scrollView.alwaysBounceVertical = false
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
        let coord = context.coordinator
        let fontChanged = coord.fontSize != fontSize
        let lineChanged = coord.lineSpacing != lineSpacing
        let themeChanged = coord.textColor != textColor || coord.backgroundColor != backgroundColor
        let processingChanged = coord.delRubyTag != delRubyTag || coord.delHTag != delHTag
        let customChanged = coord.customCSS != customCSS

        coord.fontSize = fontSize
        coord.lineSpacing = lineSpacing
        coord.textColor = textColor
        coord.backgroundColor = backgroundColor
        coord.delRubyTag = delRubyTag
        coord.delHTag = delHTag
        coord.customCSS = customCSS
        coord.webView = webView

        if themeChanged {
            webView.backgroundColor = UIColor(backgroundColor)
            webView.scrollView.backgroundColor = UIColor(backgroundColor)
        }

        if webView.url != htmlURL {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseURL)
            return
        }

        if fontChanged || lineChanged || themeChanged || customChanged {
            coord.reapplyStyle()
        }

        if processingChanged {
            coord.applyContentProcessing()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTap: onTap,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            textColor: textColor,
            backgroundColor: backgroundColor,
            delRubyTag: delRubyTag,
            delHTag: delHTag,
            customCSS: customCSS,
            preserveBookTypography: preserveBookTypography
        )
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIGestureRecognizerDelegate {
        var onTap: (() -> Void)?
        var fontSize: CGFloat
        var lineSpacing: CGFloat
        var textColor: Color
        var backgroundColor: Color
        var delRubyTag: Bool
        var delHTag: Bool
        var customCSS: String?
        var preserveBookTypography: Bool
        weak var webView: WKWebView?

        init(
            onTap: (() -> Void)?,
            fontSize: CGFloat,
            lineSpacing: CGFloat,
            textColor: Color,
            backgroundColor: Color,
            delRubyTag: Bool,
            delHTag: Bool,
            customCSS: String?,
            preserveBookTypography: Bool
        ) {
            self.onTap = onTap
            self.fontSize = fontSize
            self.lineSpacing = lineSpacing
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.delRubyTag = delRubyTag
            self.delHTag = delHTag
            self.customCSS = customCSS
            self.preserveBookTypography = preserveBookTypography
        }

        @objc func handleTap() {
            onTap?()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        // 重注入 CSS 到 id="legado-style" 的 <style> 标签；不存在则创建
        func reapplyStyle() {
            guard let wv = webView else { return }
            let width = wv.bounds.width
            let height = wv.bounds.height
            guard width > 0, height > 0 else { return }

            let textColorHex = UIColor(textColor).hexString
            let bgColorHex = UIColor(backgroundColor).hexString
            let css = EPUBStyleMapper.generateCSS(
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                textColor: textColorHex,
                backgroundColor: bgColorHex,
                width: width,
                height: height,
                customCSS: customCSS,
                preserveBookTypography: preserveBookTypography
            )
            let escaped = css
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")

            let js = """
            (function(){
              var id='legado-style';
              var s=document.getElementById(id);
              if(!s){s=document.createElement('style');s.id=id;document.head.appendChild(s);}
              s.innerHTML=`\(escaped)`;
              document.body.style.backgroundColor='\(bgColorHex)';
              document.body.style.color='\(textColorHex)';
            })();
            """
            wv.evaluateJavaScript(js, completionHandler: nil)
        }

        // 应用 Ruby/H 标签移除；image -> img 转换在 didFinish 一次即可
        func applyContentProcessing() {
            guard let wv = webView else { return }
            let js = """
            (function(){
              if (\(delRubyTag)) {
                document.querySelectorAll('rp, rt').forEach(function(el){el.remove();});
              }
              if (\(delHTag)) {
                document.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(function(el){el.remove();});
              }
            })();
            """
            wv.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
            let width = webView.bounds.width
            let height = webView.bounds.height
            let textColorHex = UIColor(textColor).hexString
            let bgColorHex = UIColor(backgroundColor).hexString

            let css = EPUBStyleMapper.generateCSS(
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                textColor: textColorHex,
                backgroundColor: bgColorHex,
                width: width,
                height: height,
                customCSS: customCSS,
                preserveBookTypography: preserveBookTypography
            )
            let escaped = css
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")

            let js = """
            (function() {
                var id = 'legado-style';
                var style = document.getElementById(id);
                if (!style) {
                    style = document.createElement('style');
                    style.id = id;
                    document.head.appendChild(style);
                }
                style.innerHTML = `\(escaped)`;

                if (\(delRubyTag)) {
                    document.querySelectorAll('rp, rt').forEach(function(el){el.remove();});
                }
                if (\(delHTag)) {
                    document.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(function(el){el.remove();});
                }

                document.querySelectorAll('image').forEach(function(img) {
                    var xlinkHref = img.getAttribute('xlink:href');
                    if (xlinkHref) {
                        img.outerHTML = '<img src="' + xlinkHref + '">';
                    }
                });
            })();
            """

            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                if url.scheme == "legado-epub" {
                    decisionHandler(.allow)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

class EPUBResourceHandler: NSObject, WKURLSchemeHandler {
    let epubBook: EPUBParser.EPUBBook
    
    init(epubBook: EPUBParser.EPUBBook) {
        self.epubBook = epubBook
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "EPUBResourceHandler", code: -1, userInfo: nil))
            return
        }
        
        let path = url.path
        
        if path == "cover.jpeg" {
            if let coverData = epubBook.coverImage {
                let response = URLResponse(url: url, mimeType: "image/jpeg", expectedContentLength: coverData.count, textEncodingName: nil)
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(coverData)
                urlSchemeTask.didFinish()
            } else {
                urlSchemeTask.didFailWithError(NSError(domain: "EPUBResourceHandler", code: -2, userInfo: nil))
            }
            return
        }
        
        if let imageData = EPUBParser.getImage(book: epubBook, href: path) {
            let mimeType = path.hasSuffix(".png") ? "image/png" : 
                           path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") ? "image/jpeg" :
                           path.hasSuffix(".gif") ? "image/gif" :
                           path.hasSuffix(".svg") ? "image/svg+xml" : "image/png"
            
            let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: imageData.count, textEncodingName: nil)
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(imageData)
            urlSchemeTask.didFinish()
            return
        }
        
        let decodedPath = path.removingPercentEncoding ?? path
        let fullPath = epubBook.epubDirectory.appendingPathComponent(decodedPath)
        
        if FileManager.default.fileExists(atPath: fullPath.path) {
            do {
                let data = try Data(contentsOf: fullPath)
                let mimeType = fullPath.pathExtension == "css" ? "text/css" :
                               fullPath.pathExtension == "js" ? "application/javascript" :
                               fullPath.pathExtension == "html" || fullPath.pathExtension == "xhtml" ? "text/html" :
                               fullPath.pathExtension == "ttf" || fullPath.pathExtension == "otf" ? "font/opentype" :
                               "application/octet-stream"
                
                let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            } catch {
                urlSchemeTask.didFailWithError(error)
            }
        } else {
            urlSchemeTask.didFailWithError(NSError(domain: "EPUBResourceHandler", code: -3, userInfo: [NSLocalizedDescriptionKey: "Resource not found: \(path)"]))
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    }
}

class EPUBStyleMapper {
    static func generateCSS(
        fontSize: CGFloat,
        lineSpacing: CGFloat,
        textColor: String,
        backgroundColor: String,
        width: CGFloat,
        height: CGFloat,
        customCSS: String?,
        preserveBookTypography: Bool = false
    ) -> String {
        let baseCSS = """
        html {
            height: \(height)px;
            overflow-x: auto;
            overflow-y: hidden;
            background-color: \(backgroundColor);
        }
        body {
            margin: 0;
            padding: 0;
            height: \(height)px;
            -webkit-column-width: \(width)px;
            -webkit-column-gap: 0;
            -webkit-column-fill: auto;
            background-color: \(backgroundColor);
            color: \(textColor);
            font-size: \(fontSize)px;
            line-height: \(lineSpacing);
        }
        """

        // 精装书：保留原书 CSS（h1.head / p.kaiti / span.xinli / .booktitle 等特殊排版），
        // 只覆盖基础背景色/文字色/字号/行距。
        if preserveBookTypography {
            let override = """
            /* legado minimal override for hardcover EPUB */
            body, body * {
                background-color: transparent !important;
            }
            body {
                background-color: \(backgroundColor) !important;
                color: \(textColor);
                font-size: \(fontSize)px;
                line-height: \(lineSpacing);
            }
            img, svg, image {
                max-width: 100%;
                height: auto;
            }
            """
            if let custom = customCSS {
                return baseCSS + "\n" + override + "\n" + custom
            }
            return baseCSS + "\n" + override
        }

        // 普通 EPUB 或无 CSS 的简单 EPUB：应用完整排版/图片样式
        let typographyCSS = """
        body {
            font-family: "Songti SC", "SimSun", "STSong", serif;
            text-align: justify;
            text-indent: 2em;
        }
        body > * {
            display: block;
            padding: 16px 12px;
        }
        h1, h2, h3, h4, h5, h6 {
            text-indent: 0;
            margin: 0.5em 0;
            font-weight: bold;
        }
        h1.head {
            font-family: "STSongti-SC-Bold", "SimSun", serif;
            font-size: 1.4em;
            color: #BA2213;
            text-align: center;
        }
        h2.head {
            font-family: "STHeiti", "SimHei", sans-serif;
            font-size: 1.2em;
            color: #3f83e8;
            border-bottom: 1px solid #3f83e8;
            padding-bottom: 0.3em;
        }
        h3 {
            font-family: "STHeiti", "SimHei", sans-serif;
            color: #3f83e8;
            border-left: 3px solid #3f83e8;
            padding-left: 0.5em;
        }
        h4 {
            font-family: "STHeiti", "SimHei", sans-serif;
            text-align: center;
        }
        p.kaiti {
            font-family: "Kaiti SC", "STKaiti", "KaiTi", serif;
        }
        p.fangsong {
            font-family: "FangSong", "STFangsong", serif;
        }
        span.xinli {
            font-family: "Kaiti SC", "STKaiti", "KaiTi", serif;
            color: #228B22;
        }
        .booktitle {
            font-family: "STSongti-SC-Bold", "SimSun", serif;
            font-size: 1.3em;
            text-align: center;
            margin: 1em 0;
        }
        .bookauthor {
            font-family: "FangSong", "STFangsong", serif;
            text-align: center;
            margin: 0.5em 0;
        }
        .bookpub {
            font-family: "Kaiti SC", "STKaiti", "KaiTi", serif;
            text-align: center;
            margin: 0.5em 0;
        }
        .vol {
            font-family: "STSongti-SC-Bold", "SimSun", serif;
            font-size: 1.2em;
            text-align: center;
            margin: 1em 0;
        }
        .cp {
            font-family: "Kaiti SC", "STKaiti", "KaiTi", serif;
            text-align: center;
            margin: 0.5em 0;
        }
        .foot {
            margin-top: 30%;
            font-size: 0.8em;
        }
        """

        let imageCSS = """
        img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 10px auto;
        }
        .duokan-image-single {
            text-align: center;
            margin: 1em 0;
        }
        .duokan-image-single img {
            max-width: 90%;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
        }
        .picture-80 img {
            width: 80%;
        }
        """

        let combinedCSS = baseCSS + "\n" + typographyCSS + "\n" + imageCSS

        if let custom = customCSS {
            return combinedCSS + "\n" + custom
        }

        return combinedCSS
    }
    
    static func generateFontsCSS() -> String {
        return """
        @font-face {
            font-family: 'zw';
            src: local('Songti SC'), local('SimSun'), local('STSong');
        }
        @font-face {
            font-family: 'fs';
            src: local('FangSong'), local('STFangsong');
        }
        @font-face {
            font-family: 'kt';
            src: local('Kaiti SC'), local('STKaiti'), local('KaiTi');
        }
        @font-face {
            font-family: 'ht';
            src: local('STHeiti'), local('SimHei'), local('Heiti SC');
        }
        """
    }
}
