import Foundation

// MARK: - JSON 工具

enum GSONUtils {

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    // MARK: 反序列化

    static func fromJsonObject<T: Decodable>(_ json: String?, as type: T.Type) -> Result<T, Error> {
        Result {
            guard let json else {
                throw NSError(domain: "GSONUtils", code: 1, userInfo: [NSLocalizedDescriptionKey: "解析字符串为空"])
            }
            let data = Data(json.utf8)
            return try decoder.decode(T.self, from: data)
        }
    }

    static func fromJsonArray<T: Decodable>(_ json: String?, as type: T.Type) -> Result<[T], Error> {
        Result {
            guard let json else {
                throw NSError(domain: "GSONUtils", code: 2, userInfo: [NSLocalizedDescriptionKey: "解析字符串为空"])
            }
            let data = Data(json.utf8)
            return try decoder.decode([T].self, from: data)
        }
    }

    static func fromJsonObject<T: Decodable>(_ inputStream: InputStream?, as type: T.Type) -> Result<T, Error> {
        Result {
            guard let inputStream else {
                throw NSError(domain: "GSONUtils", code: 3, userInfo: [NSLocalizedDescriptionKey: "解析流为空"])
            }
            let data = IOUtils.toData(from: inputStream)
            return try decoder.decode(T.self, from: data)
        }
    }

    static func fromJsonArray<T: Decodable>(_ inputStream: InputStream?, as type: T.Type) -> Result<[T], Error> {
        Result {
            guard let inputStream else {
                throw NSError(domain: "GSONUtils", code: 4, userInfo: [NSLocalizedDescriptionKey: "解析流为空"])
            }
            let data = IOUtils.toData(from: inputStream)
            return try decoder.decode([T].self, from: data)
        }
    }

    // MARK: 序列化

    static func toJSONString<T: Encodable>(_ value: T) -> String? {
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func writeToOutputStream<T: Encodable>(_ outputStream: OutputStream, value: T) throws {
        let data = try encoder.encode(value)
        outputStream.open()
        defer { outputStream.close() }

        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            var written = 0
            while written < data.count {
                let count = outputStream.write(baseAddress + written, maxLength: data.count - written)
                if count <= 0 {
                    throw outputStream.streamError ?? NSError(domain: "GSONUtils", code: 5)
                }
                written += count
            }
        }
    }

    // MARK: 非强类型

    static func jsonObject(from json: String) -> Any? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    static func jsonDictionary(from json: String) -> [String: Any]? {
        jsonObject(from: json) as? [String: Any]
    }

    static func jsonArray(from json: String) -> [Any]? {
        jsonObject(from: json) as? [Any]
    }
}
