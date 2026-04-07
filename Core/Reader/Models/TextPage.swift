//
//  TextPage.swift
//  Legado
//
//  基于 Android Legado 原版 TextPage.kt 移植
//  原版路径: app/src/main/java/io/legado/app/ui/book/read/page/entities/TextPage.kt
//

import UIKit
import Foundation

/// 页面信息
/// 一比一移植自 Android Legado TextPage 数据类
/// 用于表示章节中的一页内容
class TextPage {
    var index: Int = 0
    var text: String = "加载中..."
    var title: String = "加载中..."
    private var textLines: [TextLine] = []
    var chapterSize: Int = 0
    var chapterIndex: Int = 0
    var height: Float = 0.0
    var leftLineSize: Int = 0
    var renderHeight: Int = 0
    
    static let empty = TextPage()
    
    var lines: [TextLine] { textLines }
    var lineSize: Int { textLines.count }
    var charSize: Int { max(text.count, 1) }
    var chapterPosition: Int { textLines.first?.chapterPosition ?? 0 }
    var searchResult: Set<TextColumn> = []
    var isMsgPage: Bool = false
    var isCompleted: Bool = false
    var hasReadAloudSpan: Bool = false
    
    var textChapter: TextChapter = TextChapter.empty
    
    func addLine(_ line: TextLine) {
        line.textPage = self
        textLines.append(line)
    }
    
    func getLine(_ index: Int) -> TextLine {
        return textLines.indices.contains(index) ? textLines[index] : textLines.last!
    }
    
    func upLinesPosition() {
        // TODO: 实现底部对齐更新行位置逻辑
        // 参考 Android 原版 TextPage.kt upLinesPosition()
    }
    
    func getPosByLineColumn(lineIndex: Int, columnIndex: Int) -> Int {
        var length = 0
        let maxIndex = min(lineIndex, lineSize - 1)
        
        for index in 0..<maxIndex {
            length += textLines[index].charSize
            if textLines[index].isParagraphEnd {
                length += 1
            }
        }
        
        let columns = textLines[maxIndex].columns
        for index in 0..<columnIndex {
            if let column = columns[index] as? TextColumn {
                length += column.charData.count
            }
        }
        
        return length
    }
    
    func containPos(_ chapterPos: Int) -> Bool {
        guard let firstLine = lines.first else { return false }
        let startPos = firstLine.chapterPosition
        let endPos = startPos + charSize
        return chapterPos >= startPos && chapterPos < endPos
    }
    
    var readProgress: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        
        if chapterSize == 0 || (textChapter.pageSize == 0 && chapterIndex == 0) {
            return "0.0%"
        } else if textChapter.pageSize == 0 {
            return formatter.string(from: NSNumber(value: Float(chapterIndex + 1) / Float(chapterSize))) ?? "0.0%"
        }
        
        var percent = Float(chapterIndex) / Float(chapterSize)
        percent += Float(1) / Float(chapterSize) * Float(index + 1) / Float(textChapter.pageSize)
        
        let result = formatter.string(from: NSNumber(value: percent)) ?? "0.0%"
        if result == "100.0%" && (chapterIndex + 1 != chapterSize || index + 1 != textChapter.pageSize) {
            return "99.9%"
        }
        return result
    }
    
    func draw(in view: ContentTextView, context: CGContext, relativeOffset: Float) {
        // TODO: 实现页面绘制逻辑
        context.saveGState()
        context.translateBy(x: 0, y: relativeOffset)
        
        for line in lines {
            context.saveGState()
            context.translateBy(x: 0, y: line.lineTop)
            line.draw(in: view, context: context)
            context.restoreGState()
        }
        
        context.restoreGState()
    }
    
    func invalidate() {
        // TODO: 实现 canvas recorder invalidation
    }
    
    func invalidateAll() {
        for line in lines {
            line.invalidateSelf()
        }
        invalidate()
    }
    
    func hasImageOrEmpty() -> Bool {
        return textLines.contains { $0.isImage } || textLines.isEmpty
    }
    
    func upRenderHeight() {
        renderHeight = Int(ceil(lines.last?.lineBottom ?? 0))
        if leftLineSize > 0 && leftLineSize != lines.count {
            let leftHeight = Int(ceil(lines[leftLineSize - 1].lineBottom))
            renderHeight = max(renderHeight, leftHeight)
        }
    }
}