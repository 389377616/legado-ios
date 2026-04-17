import UIKit

class TextMeasure {
    private(set) var font: UIFont
    private let chineseCommonWidth: CGFloat
    private var asciiWidths: [CGFloat] = Array(repeating: -1, count: 128)
    private var codePointWidths: [Int: CGFloat] = [:]
    
    init(font: UIFont) {
        self.font = font
        self.chineseCommonWidth = measureText("一")
    }
    
    private func measureCodePoint(codePoint: Int) -> CGFloat {
        if codePoint < 128 {
            return asciiWidths[codePoint]
        }
        if codePoint >= 19968 && codePoint <= 40869 {
            return chineseCommonWidth
        }
        return codePointWidths[codePoint] ?? -1
    }
    
    private func measureCodePoints(codePoints: [Int]) {
        let text = String(codePoints.map { Character(UnicodeScalar($0) ?? UnicodeScalar(32)) })
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        var widths: [CGFloat] = []
        for i in 0..<text.utf16.count {
            let range = NSRange(location: i, length: 1)
            let width = attributedString.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: font.lineHeight), options: .usesLineFragmentOrigin, context: nil).width
            widths.append(ceil(width))
        }
        
        var charIndex = 0
        for i in codePoints.indices {
            let codePoint = codePoints[i]
            if charIndex < widths.count {
                let width = widths[charIndex]
                if codePoint < 128 {
                    asciiWidths[codePoint] = width
                } else {
                    codePointWidths[codePoint] = width
                }
                charIndex += 1
            }
        }
    }
    
    func measureTextSplit(text: String) -> (strings: [String], widths: [CGFloat]) {
        var needMeasureCodePoints: Set<Int>? = nil
        let codePoints = textToCodePoints(text)
        let size = codePoints.count
        var widths: [CGFloat] = Array(repeating: 0, count: size)
        var stringList: [String] = Array(repeating: "", count: size)
        
        for i in codePoints.indices {
            let codePoint = codePoints[i]
            let width = measureCodePoint(codePoint)
            widths[i] = width
            if width == -1 {
                if needMeasureCodePoints == nil {
                    needMeasureCodePoints = Set<Int>()
                }
                needMeasureCodePoints!.insert(codePoint)
            }
            if let scalar = UnicodeScalar(codePoint) {
                stringList[i] = String(Character(scalar))
            } else {
                stringList[i] = " "
            }
        }
        
        if let needMeasure = needMeasureCodePoints, !needMeasure.isEmpty {
            measureCodePoints(Array(needMeasure))
            for i in codePoints.indices {
                if widths[i] == -1 {
                    widths[i] = measureCodePoint(codePoints[i])
                }
            }
        }
        
        return (stringList, widths)
    }
    
    func measureText(text: String) -> CGFloat {
        var textWidth: CGFloat = 0
        var needMeasureCodePoints: [Int]? = nil
        let codePoints = textToCodePoints(text)
        
        for i in codePoints.indices {
            let codePoint = codePoints[i]
            let width = measureCodePoint(codePoint)
            if width == -1 {
                if needMeasureCodePoints == nil {
                    needMeasureCodePoints = []
                }
                needMeasureCodePoints!.append(codePoint)
                continue
            }
            textWidth += width
        }
        
        if let needMeasure = needMeasureCodePoints, !needMeasure.isEmpty {
            measureCodePoints(Array(Set(needMeasure)))
            for i in needMeasure.indices {
                textWidth += measureCodePoint(needMeasure[i])
            }
        }
        
        return textWidth
    }
    
    private func textToCodePoints(text: String) -> [Int] {
        var codePoints: [Int] = []
        for scalar in text.unicodeScalars {
            codePoints.append(scalar.value)
        }
        return codePoints
    }
    
    func setFont(_ font: UIFont) {
        self.font = font
        invalidate()
    }
    
    private func invalidate() {
        codePointWidths.removeAll()
        for i in 0..<128 {
            asciiWidths[i] = -1
        }
    }
    
    private func measureText(_ text: String) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = text.size(withAttributes: attributes)
        return size.width
    }
}