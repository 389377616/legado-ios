//
//  ImageColumn.swift
//  Legado
//
//  基于 Android Legado 原版 ImageColumn.kt 移植
//  原版路径: app/src/main/java/io/legado/app/ui/book/read/page/entities/column/ImageColumn.kt
//

import UIKit

/// 图片列
/// 一比一移植自 Android Legado ImageColumn 数据类
/// 用于表示页面中的图片内容
class ImageColumn: BaseColumn {
    var start: Float
    var end: Float
    var src: String
    var textLine: TextLine = TextLine.empty
    
    init(start: Float, end: Float, src: String) {
        self.start = start
        self.end = end
        self.src = src
    }
    
    func draw(in view: ContentTextView, context: CGContext) {
        // TODO: 实现图片绘制逻辑
        // 需要通过 ImageProvider 获取图片
        // 需要根据 textLine.isImage 判断绘制方式
    }
}