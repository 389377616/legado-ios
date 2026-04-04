import Foundation

final class LocalBookScanner {
    static let shared = LocalBookScanner()

    private let defaults = UserDefaults.standard
    private let scannedPathsKey = "local_book_scanned_paths_v1"
    private var scannedPaths: Set<String>
    private let supportedExtensions: Set<String> = ["txt", "epub"]

    private init() {
        let saved = defaults.stringArray(forKey: scannedPathsKey) ?? []
        scannedPaths = Set(saved)
    }

    func scanDirectory(url: URL) -> [URL] {
        scanDirectory(url: url, recursive: true, progress: nil)
    }

    func scanDirectory(
        url: URL,
        recursive: Bool,
        progress: ((Int, Int, Int) -> Void)? = nil
    ) -> [URL] {
        let rootURL = url.standardizedFileURL
        let fileURLs = collectFileURLs(in: rootURL, recursive: recursive)
        let total = fileURLs.count
        var processed = 0
        var found: [URL] = []

        for fileURL in fileURLs {
            processed += 1
            guard isSupported(fileURL), !isScanned(fileURL) else {
                progress?(processed, total, found.count)
                continue
            }

            found.append(fileURL.standardizedFileURL)
            progress?(processed, total, found.count)
        }

        return found.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    func isScanned(_ url: URL) -> Bool {
        scannedPaths.contains(normalizedPath(for: url))
    }

    func markScanned(_ url: URL) {
        scannedPaths.insert(normalizedPath(for: url))
        defaults.set(Array(scannedPaths).sorted(), forKey: scannedPathsKey)
    }

    func markScanned(_ urls: [URL]) {
        var changed = false
        for url in urls {
            let key = normalizedPath(for: url)
            if scannedPaths.insert(key).inserted {
                changed = true
            }
        }

        if changed {
            defaults.set(Array(scannedPaths).sorted(), forKey: scannedPathsKey)
        }
    }

    private func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path.lowercased()
    }

    private func collectFileURLs(in rootURL: URL, recursive: Bool) -> [URL] {
        let fileManager = FileManager.default
        var result: [URL] = []

        if recursive {
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }

            for case let fileURL as URL in enumerator {
                if isRegularFile(fileURL) {
                    result.append(fileURL)
                }
            }
        } else {
            guard let fileURLs = try? fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }

            result = fileURLs.filter { isRegularFile($0) }
        }

        return result
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
    }
}
