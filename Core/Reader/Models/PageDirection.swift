//
//  PageDirection.swift
//  Legado
//
//  基于 Android Legado 原版 PageDirection.kt 移植
//  原版路径: app/src/main/java/io/legado/app/ui/book/read/page/entities/PageDirection.kt
//

import Foundation

/// 翻页方向
/// 一比一移植自 Android Legado PageDirection 枚举
enum PageDirection {
    case none    // 无翻页
    case prev    // 上一页
    case next    // 下一页
}