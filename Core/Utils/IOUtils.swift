import Foundation

// MARK: - IO 工具

enum IOUtils {

    // MARK: InputStream

    static func toData(from inputStream: InputStream, bufferSize: Int = 4_096) -> Data {
        inputStream.open()
        defer { inputStream.close() }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while inputStream.hasBytesAvailable {
            let readCount = inputStream.read(buffer, maxLength: bufferSize)
            if readCount < 0 {
                break
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }
        return data
    }

    static func toString(
        from inputStream: InputStream,
        encoding: String.Encoding = .utf8
    ) -> String {
        String(data: toData(from: inputStream), encoding: encoding) ?? ""
    }

    static func copy(
        from inputStream: InputStream,
        to outputStream: OutputStream,
        bufferSize: Int = 4_096
    ) -> Int {
        inputStream.open()
        outputStream.open()
        defer {
            inputStream.close()
            outputStream.close()
        }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var totalWritten = 0
        while inputStream.hasBytesAvailable {
            let readCount = inputStream.read(buffer, maxLength: bufferSize)
            if readCount <= 0 { break }

            var writtenOffset = 0
            while writtenOffset < readCount {
                let writeCount = outputStream.write(buffer + writtenOffset, maxLength: readCount - writtenOffset)
                if writeCount <= 0 { return totalWritten }
                writtenOffset += writeCount
                totalWritten += writeCount
            }
        }
        return totalWritten
    }

    // MARK: 内容判断

    static func isJSON(_ inputStream: InputStream?) -> Bool {
        guard let inputStream else { return false }
        let text = toString(from: inputStream).trimmingCharacters(in: .whitespacesAndNewlines)
        return (text.hasPrefix("{") && text.hasSuffix("}")) || (text.hasPrefix("[") && text.hasSuffix("]"))
    }

    static func contains(_ inputStream: InputStream?, string: String) -> Bool {
        guard let inputStream else { return false }
        return toString(from: inputStream).contains(string)
    }

    // MARK: 安静关闭

    static func closeSilently(_ stream: Stream?) {
        stream?.close()
    }
}
