import Foundation

final class UmdFileParser {

    struct ParsedBook {
        let title: String
        let author: String?
        let chapters: [String]
    }

    static func parse(file url: URL) throws -> ParsedBook {
        // TODO: 对齐 Android UmdFile.kt：补充 UMD 头信息、章节标题表、zlib 内容解压与编码转换。
        throw LocalFileParserStubError.notImplemented("UMD 本地解析尚未移植")
    }

    static func readChapter(file url: URL, chapterIndex: Int) throws -> String {
        // TODO: 按章节偏移提取并解码 UMD 正文内容。
        throw LocalFileParserStubError.notImplemented("UMD 章节读取尚未移植")
    }
}
