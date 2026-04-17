import Foundation

public enum EPUBViewMode: String, Codable, CaseIterable {
    case paged = "readium-paged-on"
    case scroll = "readium-scroll-on"
    
    public var displayName: String {
        switch self {
        case .paged: return "分页"
        case .scroll: return "滚动"
        }
    }
}

public enum Theme: String, Codable, CaseIterable {
    case neutral
    case sepia
    case night
    case paper
    case contrast1
    case contrast2
    case contrast3
    case contrast4
    
    public var displayName: String {
        switch self {
        case .neutral: return "默认"
        case .sepia: return "护眼"
        case .night: return "夜间"
        case .paper: return "纸张"
        case .contrast1: return "高对比1"
        case .contrast2: return "高对比2"
        case .contrast3: return "高对比3"
        case .contrast4: return "高对比4"
        }
    }
    
    public var backgroundColor: String {
        switch self {
        case .neutral: return "#FFFFFF"
        case .sepia: return "#FAF4E8"
        case .night: return "#121212"
        case .paper: return "#E9DDC8"
        case .contrast1: return "#000000"
        case .contrast2: return "#000000"
        case .contrast3: return "#181842"
        case .contrast4: return "#C5E7CD"
        }
    }
    
    public var textColor: String {
        switch self {
        case .neutral: return "#000000"
        case .sepia: return "#000000"
        case .night: return "#FFFFFF"
        case .paper: return "#000000"
        case .contrast1: return "#FFFFFF"
        case .contrast2: return "#FFFF00"
        case .contrast3: return "#FFFFFF"
        case .contrast4: return "#000000"
        }
    }
}

public enum FontFamily: String, Codable, CaseIterable {
    case oldStyle = "oldStyle"
    case modern = "modern"
    case sans = "sans"
    case humanist = "humanist"
    
    public var displayName: String {
        switch self {
        case .oldStyle: return "衬线（旧式）"
        case .modern: return "衬线（现代）"
        case .sans: return "无衬线"
        case .humanist: return "人文无衬线"
        }
    }
    
    public var cssVariable: String {
        switch self {
        case .oldStyle: return "var(--RS__oldStyleTf)"
        case .modern: return "var(--RS__modernTf)"
        case .sans: return "var(--RS__sansTf)"
        case .humanist: return "var(--RS__humanistTf)"
        }
    }
}

public enum TextAlign: String, Codable, CaseIterable {
    case start = "start"
    case justify = "justify"
    case left = "left"
    case right = "right"
    
    public var displayName: String {
        switch self {
        case .start: return "自动"
        case .justify: return "两端对齐"
        case .left: return "左对齐"
        case .right: return "右对齐"
        }
    }
}

public enum HyphensMode: String, Codable, CaseIterable {
    case auto = "auto"
    case none = "none"
    
    public var displayName: String {
        switch self {
        case .auto: return "自动连字符"
        case .none: return "禁用连字符"
        }
    }
}

public struct EPUBPreferences: Codable, Equatable {
    
    public var view: EPUBViewMode = .paged
    
    public var columnCount: Int = 1
    public var lineLength: Double?
    
    public var theme: Theme = .neutral
    public var backgroundColor: String?
    public var textColor: String?
    
    public var fontFamily: FontFamily = .sans
    public var fontSize: Double = 1.0
    public var fontWeight: Double?
    public var lineHeight: Double = 1.5
    
    public var textAlign: TextAlign = .justify
    public var hyphens: HyphensMode = .auto
    
    public var paragraphSpacing: Double = 1.0
    public var paragraphIndent: Double = 1.5
    
    public var wordSpacing: Double = 0
    public var letterSpacing: Double = 0
    public var ligatures: Bool = true
    
    public var a11yNormalize: Bool = false
    public var noRuby: Bool = false
    public var publisherStyles: Bool = true
    
    public init() {}
    
    public func toCSSVariables() -> [String: String] {
        var vars: [String: String] = [:]
        
        vars["--USER__view"] = view.rawValue
        
        if columnCount > 1 {
            vars["--USER__colCount"] = "\(columnCount)"
        }
        
        if let lineLength = lineLength {
            vars["--USER__lineLength"] = "\(Int(lineLength))em"
        }
        
        vars["--USER__backgroundColor"] = backgroundColor ?? theme.backgroundColor
        vars["--USER__textColor"] = textColor ?? theme.textColor
        
        vars["--USER__fontFamily"] = fontFamily.cssVariable
        vars["--USER__fontSize"] = "\(Int(fontSize * 100))%"
        
        if let fontWeight = fontWeight {
            vars["--USER__fontWeight"] = "\(Int(fontWeight))"
        }
        
        vars["--USER__lineHeight"] = String(format: "%.1f", lineHeight)
        vars["--USER__textAlign"] = textAlign.rawValue
        vars["--USER__bodyHyphens"] = hyphens.rawValue
        
        if paragraphSpacing > 0 {
            vars["--USER__paraSpacing"] = "\(paragraphSpacing)rem"
        }
        
        if paragraphIndent > 0 {
            vars["--USER__paraIndent"] = "\(paragraphIndent)rem"
        }
        
        if wordSpacing > 0 {
            vars["--USER__wordSpacing"] = "\(wordSpacing)rem"
        }
        
        if letterSpacing > 0 {
            vars["--USER__letterSpacing"] = "\(letterSpacing)rem"
        }
        
        vars["--USER__ligatures"] = ligatures ? "common-ligatures" : "none"
        
        if a11yNormalize {
            vars["--USER__a11yNormalize"] = "readium-a11y-on"
        }
        
        if noRuby {
            vars["--USER__no-ruby"] = "readium-noRuby-on"
        }
        
        return vars
    }
    
    public static let `default` = EPUBPreferences()
}