import UIKit
import CoreText

class FontManager {
    static let shared = FontManager()
    
    private var registeredFonts: Set<String> = []
    private var fontCache: [String: UIFont] = [:]
    
    enum ChineseFontType: String, CaseIterable {
        case songti = "宋体"
        case kaiti = "楷体"
        case fangsong = "仿宋"
        case heiti = "黑体"
        case yuanTi = "圆体"
        case xiaoZhuan = "小标宋"
        
        var cssName: String {
            switch self {
            case .songti: return "zw"
            case .kaiti: return "kt"
            case .fangsong: return "fs"
            case .heiti: return "ht"
            case .yuanTi: return "yt"
            case .xiaoZhuan: return "h2"
            }
        }
        
        var systemFontName: String {
            switch self {
            case .songti: return "Songti SC"
            case .kaiti: return "Kaiti SC"
            case .fangsong: return "FangSong"
            case .heiti: return "Heiti SC"
            case .yuanTi: return "PingFang SC"
            case .xiaoZhuan: return "STSongti-SC-Bold"
            }
        }
        
        var fallbackFonts: [String] {
            switch self {
            case .songti: return ["SimSun", "STSong", "Songti SC", "Times New Roman"]
            case .kaiti: return ["KaiTi", "STKaiti", "Kaiti SC", "楷体"]
            case .fangsong: return ["FangSong", "STFangsong", "仿宋"]
            case .heiti: return ["SimHei", "STHeiti", "Heiti SC", "黑体"]
            case .yuanTi: return ["PingFang SC", "Hiragino Sans GB"]
            case .xiaoZhuan: return ["STSongti-SC-Bold", "方正小标宋"]
            }
        }
    }
    
    private init() {}
    
    func getFont(type: ChineseFontType, size: CGFloat) -> UIFont {
        let cacheKey = "\(type.rawValue)_\(size)"
        if let cached = fontCache[cacheKey] {
            return cached
        }
        
        let font = findBestFont(type: type, size: size)
        fontCache[cacheKey] = font
        return font
    }
    
    private func findBestFont(type: ChineseFontType, size: CGFloat) -> UIFont {
        for fontName in type.fallbackFonts {
            if let font = UIFont(name: fontName, size: size) {
                return font
            }
        }
        
        return UIFont.systemFont(ofSize: size)
    }
    
    func registerCustomFont(from url: URL) -> Bool {
        guard let fontData = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: fontData as CFData),
              let font = CGFont(provider) else { return false }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(font, &error)
        
        if success {
            registeredFonts.insert(url.lastPathComponent)
            fontCache.removeAll()
            return true
        }
        
        if let error = error?.takeRetainedValue() {
            let errorDescription = CFErrorCopyDescription(error)
            print("Font registration error: \(String(describing: errorDescription))")
        }
        
        return false
    }
    
    func unregisterFont(from url: URL) {
        guard let fontData = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: fontData as CFData),
              let font = CGFont(provider) else { return }
        var error: Unmanaged<CFError>?
        CTFontManagerUnregisterGraphicsFont(font, &error)
        registeredFonts.remove(url.lastPathComponent)
        fontCache.removeAll()
    }
    
    func getAvailableFontNames() -> [String] {
        return UIFont.familyNames.flatMap { family in
            UIFont.fontNames(forFamilyName: family)
        }
    }
    
    func isFontAvailable(name: String) -> Bool {
        return UIFont.fontNames(forFamilyName: name).contains(name) ||
               UIFont(name: name, size: 12) != nil
    }
    
    func generateCSSFontFamily(type: ChineseFontType) -> String {
        let cssName = type.cssName
        let systemName = type.systemFontName
        let fallbacks = type.fallbackFonts
        
        var css = "@font-face {\n"
        css += "  font-family: '\(cssName)';\n"
        
        for fallback in fallbacks {
            css += "  src: local('\(fallback)');\n"
        }
        
        css += "  font-weight: normal;\n"
        css += "  font-style: normal;\n"
        css += "}\n"
        
        return css
    }
    
    func generateAllCSSFontFamilies() -> String {
        return ChineseFontType.allCases.map { generateCSSFontFamily(type: $0) }.joined(separator: "\n")
    }
    
    func getFontForCSSName(cssName: String, size: CGFloat) -> UIFont {
        for type in ChineseFontType.allCases {
            if type.cssName == cssName {
                return getFont(type: type, size: size)
            }
        }
        
        switch cssName {
        case "zw", "宋体", "songti":
            return getFont(type: .songti, size: size)
        case "kt", "楷体", "kaiti":
            return getFont(type: .kaiti, size: size)
        case "fs", "仿宋", "fangsong":
            return getFont(type: .fangsong, size: size)
        case "ht", "黑体", "heiti":
            return getFont(type: .heiti, size: size)
        default:
            return UIFont.systemFont(ofSize: size)
        }
    }
    
    func loadBundledFonts() {
        let bundle = Bundle.main
        let fontPaths = bundle.paths(forResourcesOfType: "ttf", inDirectory: nil) +
                        bundle.paths(forResourcesOfType: "otf", inDirectory: nil)
        
        for path in fontPaths {
            let url = URL(fileURLWithPath: path)
            registerCustomFont(from: url)
        }
    }
    
    func loadFontFromDocuments(filename: String) -> Bool {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fontURL = documents.appendingPathComponent("fonts").appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: fontURL.path) {
            return registerCustomFont(from: fontURL)
        }
        
        return false
    }
    
    func copyFontToDocuments(from sourceURL: URL, filename: String) -> Bool {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fontsDir = documents.appendingPathComponent("fonts")
        
        if !FileManager.default.fileExists(atPath: fontsDir.path) {
            try? FileManager.default.createDirectory(at: fontsDir, withIntermediateDirectories: true)
        }
        
        let destURL = fontsDir.appendingPathComponent(filename)
        
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return registerCustomFont(from: destURL)
        } catch {
            print("Failed to copy font: \(error)")
            return false
        }
    }
}