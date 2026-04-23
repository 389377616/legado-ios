import Foundation

// MARK: - 时间工具

enum TimeUtils {

    // MARK: 相对时间

    static func timeAgo(from timestamp: Int64, now: Date = Date()) -> String {
        let seconds = abs(now.timeIntervalSince1970 - TimeInterval(timestamp) / 1000.0)
        let suffix = TimeInterval(timestamp) / 1000.0 <= now.timeIntervalSince1970 ? "前" : "后"

        let value: String
        switch seconds {
        case 0..<60:
            value = "\(Int(seconds))秒"
        case 60..<3_600:
            value = "\(Int(seconds / 60))分钟"
        case 3_600..<86_400:
            value = "\(Int(seconds / 3_600))小时"
        case 86_400..<604_800:
            value = "\(Int(seconds / 86_400))天"
        case 604_800..<2_628_000:
            value = "\(Int(seconds / 604_800))周"
        case 2_628_000..<31_536_000:
            value = "\(Int(seconds / 2_628_000))月"
        default:
            value = "\(Int(seconds / 31_536_000))年"
        }

        return value + suffix
    }

    static func durationTime(milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1_000
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: 格式化

    static func format(
        timestamp: TimeInterval,
        pattern: String = "yyyy-MM-dd HH:mm:ss",
        locale: Locale = Locale(identifier: "zh_CN")
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = pattern
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    static func parse(
        _ string: String,
        pattern: String,
        locale: Locale = Locale(identifier: "zh_CN")
    ) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = pattern
        return formatter.date(from: string)
    }
}
