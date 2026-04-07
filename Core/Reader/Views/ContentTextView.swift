//
//  ContentTextView.swift
//  Legado
//
//  占位文件 - 用于解决模型层编译问题
//  完整实现将在阶段 3 绘制层完成
//

import UIKit

/// 内容文本绘制视图
/// 一比一移植自 Android Legado ContentTextView
/// 用于绘制页面内容（文本、图片等）
class ContentTextView: UIView {
    
    init() {
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}