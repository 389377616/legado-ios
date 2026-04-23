import Foundation
import CryptoKit

// MARK: - MD5 工具

enum MD5Utils {

    static func md5Encode(_ string: String?) -> String {
        md5Encode(Data((string ?? "").utf8))
    }

    static func md5Encode(_ inputStream: InputStream) -> String {
        inputStream.open()
        defer { inputStream.close() }

        let bufferSize = 4_096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var hasher = Insecure.MD5()
        while inputStream.hasBytesAvailable {
            let readCount = inputStream.read(buffer, maxLength: bufferSize)
            if readCount <= 0 { break }
            hasher.update(data: Data(bytes: buffer, count: readCount))
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func md5Encode(_ data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func md5Encode16(_ string: String) -> String {
        let full = md5Encode(string)
        let start = full.index(full.startIndex, offsetBy: 8)
        let end = full.index(full.startIndex, offsetBy: 24)
        return String(full[start..<end])
    }
}
