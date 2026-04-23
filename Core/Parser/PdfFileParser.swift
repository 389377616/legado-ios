import Foundation

enum LocalFileParserStubError: LocalizedError {
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return message
        }
    }
}

final class PdfFileParser {

    struct ParsedBook {
        let title: String
        let author: String?
        let pageCount: Int
    }

    static func parse(file url: URL) throws -> ParsedBook {
        // TODO: 对齐 Android PdfFile.kt：补充 PDF 元数据、分页目录与图片页读取逻辑。
        throw LocalFileParserStubError.notImplemented("PDF 本地解析尚未移植")
    }

    static func readPage(file url: URL, pageIndex: Int) throws -> Data {
        // TODO: 解析指定 PDF 页并返回渲染后的图片或文本数据。
        throw LocalFileParserStubError.notImplemented("PDF 页面读取尚未移植")
    }
}
