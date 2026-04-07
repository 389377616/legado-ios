//
//  TextPos.swift
//  Legado
//
//  基于 Android Legado 原版 TextPos.kt 移植
//  原版路径: app/src/main/java/io/legado/app/ui/book/read/page/entities/TextPos.kt
//

import Foundation

/// 文本位置信息
/// 一比一移植自 Android Legado TextPos 数据类
/// 用于表示文本在页面中的精确位置（相对页面、行索引、列索引）
struct TextPos {
    /// 相对页面位置（-1=前一页, 0=当前页, 1=下一页）
    var relativePagePos: Int = 0
    
    /// 行索引
    var lineIndex: Int = -1
    
    /// 列索引（字符位置）
    var columnIndex: Int = -1
    
    /// 更新位置数据
    /// - Parameters:
    ///   - relativePos: 相对页面位置
    ///   - lineIndex: 行索引
    ///   - charIndex: 列索引
    func update(relativePos: Int, lineIndex: Int, charIndex: Int) -> TextPos {
        return TextPos(
            relativePagePos: relativePos,
            lineIndex: lineIndex,
            columnIndex: charIndex
        )
    }
    
    /// 从另一个 TextPos 更新数据
    func update(from pos: TextPos) -> TextPos {
        return TextPos(
            relativePagePos: pos.relativePagePos,
            lineIndex: pos.lineIndex,
            columnIndex: pos.columnIndex
        )
    }
    
    /// 比较两个位置
    /// - Returns: 比较结果 (-3~-1: 小于, 0: 相等, 1~3: 大于)
    ///   - -3: 相对页面位置更小
    ///   - -2: 行索引更小
    ///   - -1: 列索引更小
    ///   - 0: 相等
    ///   - 1: 列索引更大
    ///   - 2: 行索引更大
    ///   - 3: 相对页面位置更大
    func compare(with pos: TextPos) -> Int {
        if relativePagePos < pos.relativePagePos {
            return -3
        }
        if relativePagePos > pos.relativePagePos {
            return 3
        }
        if lineIndex < pos.lineIndex {
            return -2
        }
        if lineIndex > pos.lineIndex {
            return 2
        }
        if columnIndex < pos.columnIndex {
            return -1
        }
        if columnIndex > pos.columnIndex {
            return 1
        }
        return 0
    }
    
    /// 比较位置（参数形式）
    func compare(relativePos: Int, lineIndex: Int, charIndex: Int) -> Int {
        if self.relativePagePos < relativePos {
            return -3
        }
        if self.relativePagePos > relativePos {
            return 3
        }
        if self.lineIndex < lineIndex {
            return -2
        }
        if self.lineIndex > lineIndex {
            return 2
        }
        if self.columnIndex < charIndex {
            return -1
        }
        if self.columnIndex > charIndex {
            return 1
        }
        return 0
    }
    
    /// 重置位置
    func reset() -> TextPos {
        return TextPos(relativePagePos: 0, lineIndex: -1, columnIndex: -1)
    }
    
    /// 是否已选中（有有效位置）
    var isSelected: Bool {
        return lineIndex >= 0 && columnIndex >= 0
    }
}