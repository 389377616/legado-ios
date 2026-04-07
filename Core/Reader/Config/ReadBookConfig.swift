import Foundation

enum ReadBookConfig {
    static var paragraphIndent: ParagraphIndent = .two
    static var titleMode: Int = 0
    static var useZhLayout: Bool = true
    static var isMiddleTitle: Bool = true
    static var textFullJustify: Bool = true
    
    static var indentChar: String = "　"
}

enum ParagraphIndent: Int, CaseIterable {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    
    var length: Int { rawValue }
    var displayName: String {
        switch self {
        case .zero: return "无缩进"
        case .one: return "1字符"
        case .two: return "2字符"
        case .three: return "3字符"
        case .four: return "4字符"
        }
    }
}