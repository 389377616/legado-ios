import Foundation

final class MobiFileParser {

    struct ParsedBook {
        let title: String
        let author: String?
        let chapters: [String]
    }

    static func parse(file url: URL) throws -> ParsedBook {
        // TODO: 对齐 Android MobiFile.kt：补充 MOBI 元数据读取、章节目录构建、正文解包与 HTML 转文本。
        throw LocalFileParserStubError.notImplemented("MOBI 本地解析尚未移植")
    }

    static func readChapter(file url: URL, chapterIndex: Int) throws -> String {
        // TODO: 基于 MOBI 资源索引读取指定章节正文。
        throw LocalFileParserStubError.notImplemented("MOBI 章节读取尚未移植")
    }
}
