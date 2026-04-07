import Foundation

public enum ReaderMode {
    case legacy
    case enhanced
}

public struct EnhancedReaderModule {
    public static let version = "1.0.0"
    
    public static func isReadiumAvailable() -> Bool {
        return true
    }
}

public let readerEnhancedVersion = "1.0.0"