import Foundation
import Darwin
import SystemConfiguration

// MARK: - 网络工具

enum NetworkUtils {

    private static let queryAllowedCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "!$&()*+,-./:;=?@[\\]^_`{|}~")
        set.insert(charactersIn: "%")
        return set
    }()

    private static let formAllowedCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "*-._%")
        return set
    }()

    private static let publicSuffixExceptions: Set<String> = [
        "co.uk", "org.uk", "gov.uk", "com.cn", "net.cn", "org.cn"
    ]

    // MARK: 网络状态

    static func isAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        return withUnsafePointer(to: &zeroAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                guard let reachability = SCNetworkReachabilityCreateWithAddress(nil, socketAddress) else {
                    return false
                }

                var flags = SCNetworkReachabilityFlags()
                guard SCNetworkReachabilityGetFlags(reachability, &flags) else { return false }
                let reachable = flags.contains(.reachable)
                let requiresConnection = flags.contains(.connectionRequired)
                return reachable && !requiresConnection
            }
        }
    }

    // MARK: 编码判断

    static func encodedQuery(_ string: String) -> Bool {
        isEncoded(string, allowedCharacters: queryAllowedCharacters)
    }

    static func encodedForm(_ string: String) -> Bool {
        isEncoded(string, allowedCharacters: formAllowedCharacters)
    }

    private static func isEncoded(_ string: String, allowedCharacters: CharacterSet) -> Bool {
        let scalars = Array(string.unicodeScalars)
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if allowedCharacters.contains(scalar) {
                if scalar == "%".unicodeScalars.first {
                    guard index + 2 < scalars.count,
                          isHex(scalars[index + 1]),
                          isHex(scalars[index + 2]) else {
                        return false
                    }
                    index += 3
                    continue
                }
                index += 1
                continue
            }
            return false
        }
        return true
    }

    private static func isHex(_ scalar: UnicodeScalar) -> Bool {
        CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains(scalar)
    }

    // MARK: URL 处理

    static func getAbsoluteURL(baseURL: String?, relativePath: String) -> String {
        guard let baseURL, !baseURL.isEmpty else { return relativePath.trimmingCharacters(in: .whitespacesAndNewlines) }
        return getAbsoluteURL(baseURL: URL(string: baseURL.components(separatedBy: ",").first ?? baseURL), relativePath: relativePath)
    }

    static func getAbsoluteURL(baseURL: URL?, relativePath: String) -> String {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL else { return trimmed }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") { return trimmed }
        if trimmed.lowercased().hasPrefix("data:") { return trimmed }
        if trimmed.lowercased().hasPrefix("javascript") { return "" }
        return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL.absoluteString ?? trimmed
    }

    static func getBaseURL(_ url: String?) -> String? {
        guard let url, let components = URLComponents(string: url), let scheme = components.scheme, let host = components.host else {
            return nil
        }
        if let port = components.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    static func getSubDomain(_ url: String) -> String {
        getSubDomainOrNull(url) ?? url
    }

    static func getSubDomainOrNull(_ url: String) -> String? {
        guard let host = URL(string: getBaseURL(url) ?? "")?.host else { return nil }
        if isIPAddress(host) || host == "localhost" { return host }

        let parts = host.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return host }

        let lastTwo = parts.suffix(2).joined(separator: ".")
        if publicSuffixExceptions.contains(lastTwo), parts.count >= 3 {
            return parts.suffix(3).joined(separator: ".")
        }
        return lastTwo
    }

    static func getDomain(_ url: String) -> String {
        URL(string: getBaseURL(url) ?? "")?.host ?? url
    }

    // MARK: IP

    static func getLocalIPAddresses() -> [String] {
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            guard let addressPointer = interface.ifa_addr else { continue }
            let family = addressPointer.pointee.sa_family
            guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addressPointer,
                socklen_t(addressPointer.pointee.sa_len),
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if result == 0 {
                let address = String(cString: hostBuffer)
                if !address.hasPrefix("127.") && address != "::1" {
                    addresses.append(address)
                }
            }
        }

        return addresses
    }

    static func isIPv4Address(_ input: String?) -> Bool {
        guard let input else { return false }
        var addr = in_addr()
        return inet_pton(AF_INET, input, &addr) == 1
    }

    static func isIPv6Address(_ input: String?) -> Bool {
        guard let input else { return false }
        var addr = in6_addr()
        return inet_pton(AF_INET6, input, &addr) == 1
    }

    static func isIPAddress(_ input: String?) -> Bool {
        isIPv4Address(input) || isIPv6Address(input)
    }
}
