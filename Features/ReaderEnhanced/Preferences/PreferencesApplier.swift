import Foundation
import WebKit

public final class PreferencesApplier {
    
    public static func apply(_ prefs: EPUBPreferences, to webView: WKWebView) {
        let variables = prefs.toCSSVariables()
        
        var jsStatements: [String] = []
        for (name, value) in variables {
            let escapedValue = value.replacingOccurrences(of: "'", with: "\\'")
            jsStatements.append("document.documentElement.style.setProperty('\(name)', '\(escapedValue)');")
        }
        
        let js = jsStatements.joined(separator: "\n")
        
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("Failed to apply preferences: \(error)")
            }
        }
    }
    
    public static func reset(_ webView: WKWebView) {
        let resetJS = """
        (function() {
            const root = document.documentElement;
            const styles = root.style;
            const cssVars = [];
            for (let i = 0; i < styles.length; i++) {
                const prop = styles[i];
                if (prop.startsWith('--USER__') || prop.startsWith('--RS__')) {
                    cssVars.push(prop);
                }
            }
            for (const prop of cssVars) {
                root.style.removeProperty(prop);
            }
        })();
        """
        
        webView.evaluateJavaScript(resetJS)
    }
    
    public static func applyTheme(_ theme: Theme, to webView: WKWebView) {
        let js = """
        document.documentElement.style.setProperty('--USER__backgroundColor', '\(theme.backgroundColor)');
        document.documentElement.style.setProperty('--USER__textColor', '\(theme.textColor)');
        """
        
        webView.evaluateJavaScript(js)
    }
    
    public static func applyFontSize(_ size: Double, to webView: WKWebView) {
        let percentage = Int(size * 100)
        let js = "document.documentElement.style.setProperty('--USER__fontSize', '\(percentage)%');"
        webView.evaluateJavaScript(js)
    }
    
    public static func applyFontFamily(_ family: FontFamily, to webView: WKWebView) {
        let js = "document.documentElement.style.setProperty('--USER__fontFamily', '\(family.cssVariable)');"
        webView.evaluateJavaScript(js)
    }
    
    public static func applyLineHeight(_ height: Double, to webView: WKWebView) {
        let js = "document.documentElement.style.setProperty('--USER__lineHeight', '\(height)');"
        webView.evaluateJavaScript(js)
    }
    
    public static func setViewMode(_ mode: ViewMode, to webView: WKWebView) {
        let js = "document.documentElement.style.setProperty('--USER__view', '\(mode.rawValue)');"
        webView.evaluateJavaScript(js)
    }
    
    public static func toggleA11yNormalize(_ enabled: Bool, in webView: WKWebView) {
        let value = enabled ? "readium-a11y-on" : ""
        let js = "document.documentElement.style.setProperty('--USER__a11yNormalize', '\(value)');"
        webView.evaluateJavaScript(js)
    }
}