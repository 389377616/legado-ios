//
//  TextLine.swift
//  Legado
//
//  基于 Android Legado 原版 TextLine.kt 移植
//  原版路径: app/src/main/java/io/legado/app/ui/book/read/page/entities/TextLine.kt
//

import UIKit

/// 行信息
/// 一比一移植自 Android Legado TextLine 数据类
/// 用于表示页面中的一行文本或图片
class TextLine {
    var text: String = ""
    private var textColumns: [BaseColumn] = []
    
    var lineTop: Float = 0.0
    var lineBase: Float = 0.0
    var lineBottom: Float = 0.0
    var indentWidth: Float = 0.0
    var paragraphNum: Int = 0
    var chapterPosition: Int = 0
    var pagePosition: Int = 0
    var isTitle: Bool = false
    var isParagraphEnd: Bool = false
    var isImage: Bool = false
    var startX: Float = 0.0
    var indentSize: Int = 0
    var extraLetterSpacing: Float = 0.0
    var extraLetterSpacingOffsetX: Float = 0.0
    var wordSpacing: Float = 0.0
    var exceed: Bool = false
    var onlyTextColumn: Bool = true
    
    var textPage: TextPage = TextPage.empty
    var isLeftLine: Bool = true
    var searchResultColumnCount: Int = 0
    var isReadAloud: Bool = false {
        didSet {
            if isReadAloud != oldValue {
                invalidate()
            }
            if isReadAloud {
                textPage.hasReadAloudSpan = true
            }
        }
    }
    
    static let empty = TextLine()
    
    var columns: [BaseColumn] { textColumns }
    var charSize: Int { text.count }
    var lineStart: Float { textColumns.first?.start ?? 0.0 }
    var lineEnd: Float { textColumns.last?.end ?? 0.0 }
    var chapterIndices: Range<Int> { chapterPosition..<(chapterPosition + charSize) }
    var height: Float { lineBottom - lineTop }
    
    func addColumn(_ column: BaseColumn) {
        if !(column is TextColumn) {
            onlyTextColumn = false
        }
        column.textLine = self
        textColumns.append(column)
    }
    
    func getColumn(_ index: Int) -> BaseColumn {
        return textColumns.indices.contains(index) ? textColumns[index] : textColumns.last!
    }
    
    func getColumnReverseAt(_ index: Int, offset: Int = 0) -> BaseColumn {
        let targetIndex = textColumns.count - offset - index
        return textColumns[targetIndex]
    }
    
    func getColumnsCount() -> Int {
        return textColumns.count
    }
    
    func isTouch(x: Float, y: Float, relativeOffset: Float) -> Bool {
        return y > lineTop + relativeOffset
            && y < lineBottom + relativeOffset
            && x >= lineStart
            && x <= lineEnd
    }
    
    func isTouchY(y: Float, relativeOffset: Float) -> Bool {
        return y > lineTop + relativeOffset
            && y < lineBottom + relativeOffset
    }
    
    func draw(in view: ContentTextView, context: CGContext) {
        // TODO: 实现绘制逻辑
        for column in columns {
            column.draw(in: view, context: context)
        }
    }
    
    func invalidate() {
        invalidateSelf()
        textPage.invalidate()
    }
    
    func invalidateSelf() {
        // TODO: 实现 canvas recorder invalidation
    }
}