import Foundation

// MARK: - 数字工具

enum NumberUtils {

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    // MARK: 解析

    static func toInt(_ value: Any, default defaultValue: Int = -1) -> Int {
        Int("\(value)") ?? defaultValue
    }

    static func toDouble(_ value: Any, default defaultValue: Double = -1) -> Double {
        Double("\(value)") ?? defaultValue
    }

    static func toFloat(_ value: Any, default defaultValue: Float = -1) -> Float {
        Float("\(value)") ?? defaultValue
    }

    // MARK: 格式化

    static func formatDecimal(_ value: Double, maximumFractionDigits: Int = 2) -> String {
        decimalFormatter.maximumFractionDigits = maximumFractionDigits
        return decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func formatPercent(_ value: Double, maximumFractionDigits: Int = 2) -> String {
        percentFormatter.maximumFractionDigits = maximumFractionDigits
        return percentFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func formatFileSize(_ length: Int64) -> String {
        guard length > 0 else { return "0" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: length).lowercased()
    }

    static func hexString(of value: Int) -> String {
        String(value, radix: 16)
    }
}
