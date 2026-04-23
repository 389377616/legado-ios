import Foundation
import Compression

// MARK: - 字符串工具

enum StringUtils {

    private static let wordCountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let chineseNumberMap: [Character: Int] = [
        "零": 0, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
        "〇": 0, "壹": 1, "贰": 2, "叁": 3, "肆": 4, "伍": 5, "陆": 6, "柒": 7, "捌": 8, "玖": 9, "拾": 10,
        "两": 2, "百": 100, "佰": 100, "千": 1_000, "仟": 1_000, "万": 10_000, "亿": 100_000_000
    ]

    // MARK: 日期文本

    static func dateConvert(_ source: String, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = pattern
        guard let date = formatter.date(from: source) else { return "" }

        let now = Date()
        let diffSeconds = abs(now.timeIntervalSince(date))
        let diffMinutes = Int(diffSeconds / 60)
        let diffHours = Int(diffSeconds / 3_600)
        let diffDays = Int(diffSeconds / 86_400)

        let calendar = Calendar.current
        let hasExplicitTime = !(calendar.component(.hour, from: date) == 0 && calendar.component(.minute, from: date) == 0)

        if !hasExplicitTime {
            if calendar.isDateInToday(date) { return "今天" }
            if calendar.isDateInYesterday(date) { return "昨天" }
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }

        if diffSeconds < 60 { return "\(Int(diffSeconds))秒前" }
        if diffMinutes < 60 { return "\(diffMinutes)分钟前" }
        if diffHours < 24 { return "\(diffHours)小时前" }
        if diffDays < 2 { return "昨天" }

        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: 基础转换

    static func toFirstCapital(_ string: String) -> String {
        guard let first = string.first else { return string }
        return String(first).uppercased() + string.dropFirst()
    }

    static func halfToFull(_ input: String) -> String {
        String(input.map { character in
            guard let scalar = character.unicodeScalars.first else { return character }
            switch scalar.value {
            case 32:
                return Character(UnicodeScalar(12_288)!)
            case 33...126:
                return Character(UnicodeScalar(scalar.value + 65_248)!)
            default:
                return character
            }
        })
    }

    static func fullToHalf(_ input: String) -> String {
        String(input.map { character in
            guard let scalar = character.unicodeScalars.first else { return character }
            switch scalar.value {
            case 12_288:
                return Character(" ")
            case 65_281...65_374:
                return Character(UnicodeScalar(scalar.value - 65_248)!)
            default:
                return character
            }
        })
    }

    // MARK: 中文数字

    static func chineseNumToInt(_ text: String) -> Int {
        let normalized = fullToHalf(text).replacingOccurrences(of: " ", with: "")
        guard !normalized.isEmpty else { return -1 }

        let digitOnlySet = CharacterSet(charactersIn: "〇零一二三四五六七八九壹贰叁肆伍陆柒捌玖两")
        if normalized.unicodeScalars.allSatisfy({ digitOnlySet.contains($0) }) {
            let digits = normalized.compactMap { chineseNumberMap[$0] }.map(String.init).joined()
            return Int(digits) ?? -1
        }

        var result = 0
        var section = 0
        var number = 0

        for character in normalized {
            guard let value = chineseNumberMap[character] else { return -1 }
            switch value {
            case 0...9:
                number = number * 10 + value
            case 10, 100, 1_000:
                let base = number == 0 ? 1 : number
                section += base * value
                number = 0
            case 10_000, 100_000_000:
                section += number
                result += max(section, 1) * value
                section = 0
                number = 0
            default:
                break
            }
        }

        return result + section + number
    }

    static func stringToInt(_ string: String?) -> Int {
        guard let string else { return -1 }
        let normalized = fullToHalf(string).replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        return Int(normalized) ?? chineseNumToInt(normalized)
    }

    // MARK: 判断

    static func isContainNumber(_ string: String) -> Bool {
        string.range(of: "[0-9]+", options: .regularExpression) != nil
    }

    static func isNumeric(_ string: String) -> Bool {
        string.range(of: "^-?[0-9]+$", options: .regularExpression) != nil
    }

    // MARK: 格式化

    static func wordCountFormat(_ words: Int) -> String {
        guard words > 0 else { return "" }
        if words > 10_000 {
            let value = Double(words) / 10_000.0
            return "\(wordCountFormatter.string(from: NSNumber(value: value)) ?? "\(value)")万字"
        }
        return "\(words)字"
    }

    static func wordCountFormat(_ text: String?) -> String {
        guard let text else { return "" }
        if let value = Int(text), value > 0 {
            return wordCountFormat(value)
        }
        return text
    }

    static func trim(_ string: String) -> String {
        string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "　")))
    }

    static func repeatString(_ string: String, count: Int) -> String {
        guard count > 0 else { return "" }
        return String(repeating: string, count: count)
    }

    static func removeUTFCharacters(_ data: String?) -> String? {
        guard let data else { return nil }
        return data.replacingOccurrences(of: "\\\\u([0-9A-Fa-f]{4})", options: .regularExpression) { match in
            let hex = String(match.dropFirst(2))
            guard let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) else { return match }
            return String(scalar)
        }
    }

    static func compress(_ string: String) -> Result<String, Error> {
        Result {
            let data = Data(string.utf8)
            let compressed = try CompressionCodec.compress(data)
            return compressed.base64EncodedString()
        }
    }

    static func unCompress(_ string: String) -> Result<String, Error> {
        Result {
            let data = Data(base64Encoded: string) ?? Data()
            let decompressed = try CompressionCodec.decompress(data)
            return String(data: decompressed, encoding: .utf8) ?? ""
        }
    }
}

// MARK: - 正则替换辅助

private extension String {
    func replacingOccurrences(
        of pattern: String,
        options: String.CompareOptions,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options.contains(.caseInsensitive) ? [.caseInsensitive] : []) else {
            return self
        }

        let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self)).reversed()
        var result = self
        for match in matches {
            guard let range = Range(match.range, in: result) else { continue }
            let replacement = transform(String(result[range]))
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }
}

private enum CompressionCodec {
    static func compress(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }
        let result = data.withUnsafeBytes { sourceBuffer -> Data? in
            guard let sourcePointer = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let destCapacity = data.count
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destCapacity)
            defer { destinationBuffer.deallocate() }
            let compressedSize = compression_encode_buffer(
                destinationBuffer, destCapacity,
                sourcePointer, data.count,
                nil, COMPRESSION_ZLIB
            )
            guard compressedSize > 0 else { return nil }
            return Data(bytes: destinationBuffer, count: compressedSize)
        }
        guard let result else {
            throw NSError(domain: "StringUtils", code: 1002, userInfo: [NSLocalizedDescriptionKey: "压缩失败"])
        }
        return result
    }

    static func decompress(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }
        let destCapacity = data.count * 10 // heuristic
        let result = data.withUnsafeBytes { sourceBuffer -> Data? in
            guard let sourcePointer = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destCapacity)
            defer { destinationBuffer.deallocate() }
            let decompressedSize = compression_decode_buffer(
                destinationBuffer, destCapacity,
                sourcePointer, data.count,
                nil, COMPRESSION_ZLIB
            )
            guard decompressedSize > 0 else { return nil }
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }
        guard let result else {
            throw NSError(domain: "StringUtils", code: 1003, userInfo: [NSLocalizedDescriptionKey: "解压失败"])
        }
        return result
    }
}

// MARK: - 数据压缩/解压 (公开 API)

extension StringUtils {
    static func compress(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else { throw NSError(domain: "StringUtils", code: 1000) }
        return try CompressionCodec.compress(data)
    }

    static func decompress(_ data: Data) throws -> String {
        let decompressed = try CompressionCodec.decompress(data)
        guard let string = String(data: decompressed, encoding: .utf8) else {
            throw NSError(domain: "StringUtils", code: 1004, userInfo: [NSLocalizedDescriptionKey: "解压后字符串解码失败"])
        }
        return string
    }
}
        defer { compression_stream_destroy(&stream) }

        return try data.withUnsafeBytes { rawBuffer in
            guard let sourcePointer = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return Data() }

            stream.src_ptr = sourcePointer
            stream.src_size = data.count

            var output = Data()
            repeat {
                stream.dst_ptr = destinationBuffer
                stream.dst_size = destinationBufferSize

                status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE))
                let produced = destinationBufferSize - stream.dst_size
                if produced > 0 {
                    output.append(destinationBuffer, count: produced)
                }
            } while status == COMPRESSION_STATUS_OK

            guard status == COMPRESSION_STATUS_END else {
                throw NSError(domain: "StringUtils", code: 1002, userInfo: [NSLocalizedDescriptionKey: "压缩流处理失败"])
            }
            return output
        }
    }
}
