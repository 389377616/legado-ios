//
//  BaseColumn.swift
//  Legado
//
//  基于 Android Legato 原版 BaseColumn.kt 移植
//  原版路径: app/src/main/java/io/legado/app/ui/book/read/page/entities/column/BaseColumn.kt
//

import UIKit

/// 列基类协议
/// 一比一移植自 Android Legado BaseColumn 接口
/// 用于表示页面中的一列（字符、图片、按钮等）
protocol BaseColumn: AnyObject {
    /// 列起始位置 X
    var start: Float { get set }
    
    /// 列结束位置 X
    var end: Float { get set }
    
    /// 所属行
    var textLine: TextLine { get set }
    
    /// 绘制列内容
    /// - Parameters:
    ///   - view: 内容视图
    ///   - context: 绘制上下文
    func draw(in view: ContentTextView, context: CGContext)
}

extension BaseColumn {
    /// 判断触摸点是否在本列范围内
    func isTouch(x: Float) -> Bool {
        return x > start && x < end
    }
}