import Foundation
import Combine

@MainActor
final class AppConfigManager: ObservableObject {
    static let shared = AppConfigManager()

    private let defaults = UserDefaults.standard

    @Published var defaultHomePage: HomePage {
        didSet { defaults.set(defaultHomePage.rawValue, forKey: "app.defaultHomePage") }
    }

    @Published var showDiscoveryPage: Bool {
        didSet { defaults.set(showDiscoveryPage, forKey: "app.showDiscoveryPage") }
    }

    @Published var showRssPage: Bool {
        didSet { defaults.set(showRssPage, forKey: "app.showRssPage") }
    }

    @Published var preDownloadChapterCount: Int {
        didSet { defaults.set(preDownloadChapterCount, forKey: "reader.preDownloadChapterCount") }
    }

    @Published var autoUpdateBookToc: Bool {
        didSet { defaults.set(autoUpdateBookToc, forKey: "bookshelf.autoUpdateToc") }
    }

    @Published var autoUpdateBookTocWifiOnly: Bool {
        didSet { defaults.set(autoUpdateBookTocWifiOnly, forKey: "bookshelf.autoUpdateTocWifiOnly") }
    }

    @Published var autoClearReadBook: Bool {
        didSet { defaults.set(autoClearReadBook, forKey: "bookshelf.autoClearReadBook") }
    }

    @Published var bookshelfExportType: ExportType {
        didSet { defaults.set(bookshelfExportType.rawValue, forKey: "bookshelf.exportType") }
    }

    @Published var readAloudByPage: Bool {
        didSet { defaults.set(readAloudByPage, forKey: "reader.readAloudByPage") }
    }

    @Published var keepScreenOn: Bool {
        didSet { defaults.set(keepScreenOn, forKey: "reader.keepScreenOn") }
    }

    @Published var volumeKeyPageTurn: Bool {
        didSet { defaults.set(volumeKeyPageTurn, forKey: "reader.volumeKeyPageTurn") }
    }

    @Published var clickActionLeft: ClickAction {
        didSet { defaults.set(clickActionLeft.rawValue, forKey: "reader.clickActionLeft") }
    }

    @Published var clickActionMiddle: ClickAction {
        didSet { defaults.set(clickActionMiddle.rawValue, forKey: "reader.clickActionMiddle") }
    }

    @Published var clickActionRight: ClickAction {
        didSet { defaults.set(clickActionRight.rawValue, forKey: "reader.clickActionRight") }
    }

    @Published var brightnessFollowSystem: Bool {
        didSet { defaults.set(brightnessFollowSystem, forKey: "reader.brightnessFollowSystem") }
    }

    @Published var customBrightness: Double {
        didSet { defaults.set(customBrightness, forKey: "reader.customBrightness") }
    }

    @Published var textFullJustify: Bool {
        didSet { defaults.set(textFullJustify, forKey: "reader.textFullJustify") }
    }

    @Published var useZhLayout: Bool {
        didSet { defaults.set(useZhLayout, forKey: "reader.useZhLayout") }
    }

    @Published var paragraphIndent: Bool {
        didSet { defaults.set(paragraphIndent, forKey: "reader.paragraphIndent") }
    }

    @Published var tocReversed: Bool {
        didSet { defaults.set(tocReversed, forKey: "reader.tocReversed") }
    }

    @Published var showChapterTitle: Bool {
        didSet { defaults.set(showChapterTitle, forKey: "reader.showChapterTitle") }
    }

    @Published var showBatteryInfo: Bool {
        didSet { defaults.set(showBatteryInfo, forKey: "reader.showBatteryInfo") }
    }

    @Published var showTimeInfo: Bool {
        didSet { defaults.set(showTimeInfo, forKey: "reader.showTimeInfo") }
    }

    @Published var showPageNumber: Bool {
        didSet { defaults.set(showPageNumber, forKey: "reader.showPageNumber") }
    }

    @Published var showTotalPageNumber: Bool {
        didSet { defaults.set(showTotalPageNumber, forKey: "reader.showTotalPageNumber") }
    }

    @Published var pageAnimation: PageAnimationType {
        didSet { defaults.set(pageAnimation.rawValue, forKey: "reader.pageAnimation") }
    }

    @Published var autoPageTurnInterval: Double {
        didSet { defaults.set(autoPageTurnInterval, forKey: "reader.autoPageTurnInterval") }
    }

    @Published var fontSize: CGFloat {
        didSet { defaults.set(Double(fontSize), forKey: "reader.fontSize") }
    }

    @Published var lineSpacing: CGFloat {
        didSet { defaults.set(Double(lineSpacing), forKey: "reader.lineSpacing") }
    }

    @Published var letterSpacing: CGFloat {
        didSet { defaults.set(Double(letterSpacing), forKey: "reader.letterSpacing") }
    }

    @Published var paragraphSpacing: CGFloat {
        didSet { defaults.set(Double(paragraphSpacing), forKey: "reader.paragraphSpacing") }
    }

    @Published var topMargin: CGFloat {
        didSet { defaults.set(Double(topMargin), forKey: "reader.topMargin") }
    }

    @Published var bottomMargin: CGFloat {
        didSet { defaults.set(Double(bottomMargin), forKey: "reader.bottomMargin") }
    }

    @Published var leftMargin: CGFloat {
        didSet { defaults.set(Double(leftMargin), forKey: "reader.leftMargin") }
    }

    @Published var rightMargin: CGFloat {
        didSet { defaults.set(Double(rightMargin), forKey: "reader.rightMargin") }
    }

    @Published var maxCacheSize: Int {
        didSet { defaults.set(maxCacheSize, forKey: "cache.maxSizeMB") }
    }

    @Published var autoBackupEnabled: Bool {
        didSet { defaults.set(autoBackupEnabled, forKey: "backup.autoEnabled") }
    }

    @Published var autoBackupInterval: Int {
        didSet { defaults.set(autoBackupInterval, forKey: "backup.autoIntervalHours") }
    }

    @Published var webDavAutoSync: Bool {
        didSet { defaults.set(webDavAutoSync, forKey: "sync.webdav.autoSync") }
    }

    @Published var webDavSyncWifiOnly: Bool {
        didSet { defaults.set(webDavSyncWifiOnly, forKey: "sync.webdav.wifiOnly") }
    }

    @Published var chineseConvertMode: ChineseConvertMode {
        didSet { defaults.set(chineseConvertMode.rawValue, forKey: "reader.chineseConvertMode") }
    }

    @Published var sourceAutoUpdateEnabled: Bool {
        didSet { defaults.set(sourceAutoUpdateEnabled, forKey: "source.autoUpdateEnabled") }
    }

    @Published var sourceAutoUpdateInterval: Int {
        didSet { defaults.set(sourceAutoUpdateInterval, forKey: "source.autoUpdateIntervalHours") }
    }

    @Published var searchConcurrency: Int {
        didSet { defaults.set(searchConcurrency, forKey: "search.concurrency") }
    }

    @Published var searchTimeout: Int {
        didSet { defaults.set(searchTimeout, forKey: "search.timeoutSeconds") }
    }

    @Published var processText: Bool {
        didSet { defaults.set(processText, forKey: "reader.processText") }
    }

    @Published var replaceRuleEnabled: Bool {
        didSet { defaults.set(replaceRuleEnabled, forKey: "reader.replaceRuleEnabled") }
    }

    @Published var showUnreadBadge: Bool {
        didSet { defaults.set(showUnreadBadge, forKey: "bookshelf.showUnreadBadge") }
    }

    @Published var showUpdateTime: Bool {
        didSet { defaults.set(showUpdateTime, forKey: "bookshelf.showUpdateTime") }
    }

    @Published var bookshelfGridColumns: Int {
        didSet { defaults.set(bookshelfGridColumns, forKey: "bookshelf.gridColumns") }
    }

    @Published var bookshelfViewMode: Int {
        didSet { defaults.set(bookshelfViewMode, forKey: "bookshelf.viewMode") }
    }

    @Published var bookshelfGroupStyle: Int {
        didSet { defaults.set(bookshelfGroupStyle, forKey: "bookshelf.groupStyle") }
    }

    private init() {
        defaultHomePage = HomePage(rawValue: defaults.integer(forKey: "app.defaultHomePage")) ?? .bookshelf
        showDiscoveryPage = defaults.object(forKey: "app.showDiscoveryPage") as? Bool ?? true
        showRssPage = defaults.object(forKey: "app.showRssPage") as? Bool ?? true
        preDownloadChapterCount = defaults.object(forKey: "reader.preDownloadChapterCount") as? Int ?? 10
        autoUpdateBookToc = defaults.object(forKey: "bookshelf.autoUpdateToc") as? Bool ?? true
        autoUpdateBookTocWifiOnly = defaults.object(forKey: "bookshelf.autoUpdateTocWifiOnly") as? Bool ?? true
        autoClearReadBook = defaults.object(forKey: "bookshelf.autoClearReadBook") as? Bool ?? false
        bookshelfExportType = ExportType(rawValue: defaults.integer(forKey: "bookshelf.exportType")) ?? .nameAndAuthor
        readAloudByPage = defaults.object(forKey: "reader.readAloudByPage") as? Bool ?? false
        keepScreenOn = defaults.object(forKey: "reader.keepScreenOn") as? Bool ?? true
        volumeKeyPageTurn = defaults.object(forKey: "reader.volumeKeyPageTurn") as? Bool ?? false
        clickActionLeft = ClickAction(rawValue: defaults.integer(forKey: "reader.clickActionLeft")) ?? .prevPage
        clickActionMiddle = ClickAction(rawValue: defaults.integer(forKey: "reader.clickActionMiddle")) ?? .toggleMenu
        clickActionRight = ClickAction(rawValue: defaults.integer(forKey: "reader.clickActionRight")) ?? .nextPage
        brightnessFollowSystem = defaults.object(forKey: "reader.brightnessFollowSystem") as? Bool ?? true
        customBrightness = defaults.object(forKey: "reader.customBrightness") as? Double ?? 0.5
        textFullJustify = defaults.object(forKey: "reader.textFullJustify") as? Bool ?? true
        useZhLayout = defaults.object(forKey: "reader.useZhLayout") as? Bool ?? true
        paragraphIndent = defaults.object(forKey: "reader.paragraphIndent") as? Bool ?? true
        tocReversed = defaults.object(forKey: "reader.tocReversed") as? Bool ?? false
        showChapterTitle = defaults.object(forKey: "reader.showChapterTitle") as? Bool ?? true
        showBatteryInfo = defaults.object(forKey: "reader.showBatteryInfo") as? Bool ?? true
        showTimeInfo = defaults.object(forKey: "reader.showTimeInfo") as? Bool ?? true
        showPageNumber = defaults.object(forKey: "reader.showPageNumber") as? Bool ?? true
        showTotalPageNumber = defaults.object(forKey: "reader.showTotalPageNumber") as? Bool ?? false
        pageAnimation = PageAnimationType(rawValue: defaults.integer(forKey: "reader.pageAnimation")) ?? .simulation
        autoPageTurnInterval = defaults.object(forKey: "reader.autoPageTurnInterval") as? Double ?? 15.0
        fontSize = CGFloat(defaults.object(forKey: "reader.fontSize") as? Double ?? 18.0)
        lineSpacing = CGFloat(defaults.object(forKey: "reader.lineSpacing") as? Double ?? 1.5)
        letterSpacing = CGFloat(defaults.object(forKey: "reader.letterSpacing") as? Double ?? 0.0)
        paragraphSpacing = CGFloat(defaults.object(forKey: "reader.paragraphSpacing") as? Double ?? 8.0)
        topMargin = CGFloat(defaults.object(forKey: "reader.topMargin") as? Double ?? 44.0)
        bottomMargin = CGFloat(defaults.object(forKey: "reader.bottomMargin") as? Double ?? 44.0)
        leftMargin = CGFloat(defaults.object(forKey: "reader.leftMargin") as? Double ?? 16.0)
        rightMargin = CGFloat(defaults.object(forKey: "reader.rightMargin") as? Double ?? 16.0)
        maxCacheSize = defaults.object(forKey: "cache.maxSizeMB") as? Int ?? 100
        autoBackupEnabled = defaults.object(forKey: "backup.autoEnabled") as? Bool ?? false
        autoBackupInterval = defaults.object(forKey: "backup.autoIntervalHours") as? Int ?? 24
        webDavAutoSync = defaults.object(forKey: "sync.webdav.autoSync") as? Bool ?? false
        webDavSyncWifiOnly = defaults.object(forKey: "sync.webdav.wifiOnly") as? Bool ?? true
        chineseConvertMode = ChineseConvertMode(rawValue: defaults.integer(forKey: "reader.chineseConvertMode")) ?? .none
        sourceAutoUpdateEnabled = defaults.object(forKey: "source.autoUpdateEnabled") as? Bool ?? false
        sourceAutoUpdateInterval = defaults.object(forKey: "source.autoUpdateIntervalHours") as? Int ?? 24
        searchConcurrency = defaults.object(forKey: "search.concurrency") as? Int ?? 8
        searchTimeout = defaults.object(forKey: "search.timeoutSeconds") as? Int ?? 15
        processText = defaults.object(forKey: "reader.processText") as? Bool ?? true
        replaceRuleEnabled = defaults.object(forKey: "reader.replaceRuleEnabled") as? Bool ?? true
        showUnreadBadge = defaults.object(forKey: "bookshelf.showUnreadBadge") as? Bool ?? true
        showUpdateTime = defaults.object(forKey: "bookshelf.showUpdateTime") as? Bool ?? true
        bookshelfGridColumns = defaults.object(forKey: "bookshelf.gridColumns") as? Int ?? 3
        bookshelfViewMode = defaults.object(forKey: "bookshelf.viewMode") as? Int ?? 0
        bookshelfGroupStyle = defaults.object(forKey: "bookshelf.groupStyle") as? Int ?? 0
    }

    func resetToDefaults() {
        let keys = [
            "app.defaultHomePage", "app.showDiscoveryPage", "app.showRssPage",
            "reader.preDownloadChapterCount", "bookshelf.autoUpdateToc",
            "bookshelf.autoUpdateTocWifiOnly", "bookshelf.autoClearReadBook",
            "bookshelf.exportType", "reader.readAloudByPage", "reader.keepScreenOn",
            "reader.volumeKeyPageTurn", "reader.clickActionLeft", "reader.clickActionMiddle",
            "reader.clickActionRight", "reader.brightnessFollowSystem", "reader.customBrightness",
            "reader.textFullJustify", "reader.useZhLayout", "reader.paragraphIndent",
            "reader.tocReversed", "reader.showChapterTitle", "reader.showBatteryInfo",
            "reader.showTimeInfo", "reader.showPageNumber", "reader.showTotalPageNumber",
            "reader.pageAnimation", "reader.autoPageTurnInterval", "reader.fontSize",
            "reader.lineSpacing", "reader.letterSpacing", "reader.paragraphSpacing",
            "reader.topMargin", "reader.bottomMargin", "reader.leftMargin", "reader.rightMargin",
            "cache.maxSizeMB", "backup.autoEnabled", "backup.autoIntervalHours",
            "sync.webdav.autoSync", "sync.webdav.wifiOnly", "reader.chineseConvertMode",
            "source.autoUpdateEnabled", "source.autoUpdateIntervalHours",
            "search.concurrency", "search.timeoutSeconds", "reader.processText",
            "reader.replaceRuleEnabled", "bookshelf.showUnreadBadge", "bookshelf.showUpdateTime",
            "bookshelf.gridColumns", "bookshelf.viewMode", "bookshelf.groupStyle"
        ]
        for key in keys { defaults.removeObject(forKey: key) }
    }
}

enum HomePage: Int, CaseIterable {
    case bookshelf = 0
    case discovery = 1
    case rss = 2
    case myPage = 3

    var title: String {
        switch self {
        case .bookshelf: return "书架"
        case .discovery: return "发现"
        case .rss: return "订阅"
        case .myPage: return "我的"
        }
    }
}

enum ExportType: Int, CaseIterable {
    case nameAndAuthor = 0
    case bookUrl = 1
    case fullInfo = 2

    var title: String {
        switch self {
        case .nameAndAuthor: return "书名+作者"
        case .bookUrl: return "书籍URL"
        case .fullInfo: return "完整信息"
        }
    }
}

enum ClickAction: Int, CaseIterable {
    case none = 0
    case prevPage = 1
    case nextPage = 2
    case toggleMenu = 3
    case prevChapter = 4
    case nextChapter = 5

    var title: String {
        switch self {
        case .none: return "无操作"
        case .prevPage: return "上一页"
        case .nextPage: return "下一页"
        case .toggleMenu: return "切换菜单"
        case .prevChapter: return "上一章"
        case .nextChapter: return "下一章"
        }
    }
}

enum PageAnimationType: Int, CaseIterable {
    case cover = 0
    case simulation = 1
    case slide = 2
    case scroll = 3
    case none = 4

    var title: String {
        switch self {
        case .cover: return "覆盖"
        case .simulation: return "仿真"
        case .slide: return "滑动"
        case .scroll: return "滚动"
        case .none: return "无"
        }
    }
}

enum ChineseConvertMode: Int, CaseIterable {
    case none = 0
    case toTraditional = 1
    case toSimplified = 2

    var title: String {
        switch self {
        case .none: return "不转换"
        case .toTraditional: return "简转繁"
        case .toSimplified: return "繁转简"
        }
    }
}
