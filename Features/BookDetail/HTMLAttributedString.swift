//
//  HTMLAttributedString.swift
//  Legado-iOS
//
//  把书籍简介等 HTML 文本转换为 AttributedString 用于 SwiftUI Text
//

import Foundation
import UIKit

enum HTMLAttributedString {
    /// 仅在 main thread 调用。HTML 解析 API 在非主线程会 crash。
    static func make(from html: String, baseFontSize: CGFloat = 14) -> AttributedString {
        guard containsMarkup(html), let data = html.data(using: .utf8) else {
            return AttributedString(html)
        }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let ns = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else {
            return AttributedString(html)
        }
        let mutable = NSMutableAttributedString(attributedString: ns)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let existing = (value as? UIFont) ?? .systemFont(ofSize: baseFontSize)
            let resized = existing.withSize(baseFontSize)
            mutable.addAttribute(.font, value: resized, range: subRange)
        }
        return AttributedString(mutable)
    }

    private static func containsMarkup(_ text: String) -> Bool {
        text.contains("<") && text.contains(">")
    }
}
