//
//  TextColumn.swift
//  Legado
//
//  基于 Android Legado 原版 TextColumn.kt 移植
//  原版路径: app/src/main/java/io/legado/app/ui/book/read/page/entities/column/TextColumn.kt
//

import UIKit

/// 文字列
/// 一比一移植自 Android Legado TextColumn 数据类
/// 用于表示页面中的单个字符或字符片段
class TextColumn: BaseColumn {
    var start: Float
    var end: Float
    let charData: String
    var textLine: TextLine = TextLine.empty
    
    var selected: Bool = false {
        didSet {
            if selected != oldValue {
                textLine.invalidate()
            }
        }
    }
    
    var isSearchResult: Bool = false {
        didSet {
            if isSearchResult != oldValue {
                textLine.invalidate()
                if isSearchResult {
                    textLine.searchResultColumnCount += 1
                } else {
                    textLine.searchResultColumnCount -= 1
                }
            }
        }
    }
    
    init(start: Float, end: Float, charData: String) {
        self.start = start
        self.end = end
        self.charData = charData
    }
    
    func draw(in view: ContentTextView, context: CGContext) {
        // TODO: 实现绘制逻辑
        // 需要根据 textLine.isTitle 选择 titlePaint 或 contentPaint
        // 需要根据 isReadAloud 或 isSearchResult 选择强调色
    }
}