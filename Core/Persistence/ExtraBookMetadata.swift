//
//  ExtraBookMetadata.swift
//  Legado-iOS
//
//  Phase C 精装书扩展元数据：译者/出版社/出版日期/语言/ISBN/丛书/主题/版权
//  序列化存储在 Book.extraMetadataJson 字段里，避免 CoreData schema 每字段都加
//

import Foundation

struct ExtraBookMetadata: Codable {
    var translator: String?
    var publisher: String?
    var publishDate: String?
    var language: String?
    var isbn: String?
    var series: String?
    var subjects: [String]?
    var rights: String?

    var hasAnyField: Bool {
        [translator, publisher, publishDate, language, isbn, series, rights]
            .contains(where: { !($0 ?? "").isEmpty }) ||
            !(subjects ?? []).isEmpty
    }
}

extension ExtraBookMetadata {
    static let empty = ExtraBookMetadata()

    static func decode(from json: String?) -> ExtraBookMetadata {
        guard let json, let data = json.data(using: .utf8) else { return .empty }
        return (try? JSONDecoder().decode(ExtraBookMetadata.self, from: data)) ?? .empty
    }

    func encodeToJson() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension Book {
    var extraMetadata: ExtraBookMetadata {
        get { ExtraBookMetadata.decode(from: extraMetadataJson) }
        set { extraMetadataJson = newValue.encodeToJson() }
    }
}
