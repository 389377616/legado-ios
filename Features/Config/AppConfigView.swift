import SwiftUI

struct AppConfigView: View {
    @StateObject private var config = AppConfigManager.shared
    @State private var showingResetConfirm = false

    var body: some View {
        List {
            generalSection
            bookshelfSection
            readerSection
            readerDisplaySection
            readerBehaviorSection
            cacheSection
            backupSection
            syncSection
            searchSection
            sourceSection
            resetSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("应用配置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var generalSection: some View {
        Section("通用") {
            Picker("默认首页", selection: $config.defaultHomePage) {
                ForEach(HomePage.allCases, id: \.rawValue) { page in
                    Text(page.title).tag(page)
                }
            }

            Toggle("显示发现页", isOn: $config.showDiscoveryPage)
            Toggle("显示RSS页", isOn: $config.showRssPage)
        }
    }

    private var bookshelfSection: some View {
        Section("书架") {
            Toggle("自动更新目录", isOn: $config.autoUpdateBookToc)
            Toggle("仅WiFi下更新", isOn: $config.autoUpdateBookTocWifiOnly)
                .disabled(!config.autoUpdateBookToc)
            Toggle("自动清除已读", isOn: $config.autoClearReadBook)
            Toggle("显示未读角标", isOn: $config.showUnreadBadge)
            Toggle("显示更新时间", isOn: $config.showUpdateTime)

            Picker("导出格式", selection: $config.bookshelfExportType) {
                ForEach(ExportType.allCases, id: \.rawValue) { type in
                    Text(type.title).tag(type)
                }
            }

            Stepper("网格列数: \(config.bookshelfGridColumns)", value: $config.bookshelfGridColumns, in: 2...6)
        }
    }

    private var readerSection: some View {
        Section("阅读") {
            Picker("翻页动画", selection: $config.pageAnimation) {
                ForEach(PageAnimationType.allCases, id: \.rawValue) { type in
                    Text(type.title).tag(type)
                }
            }

            Stepper("预下载章节: \(config.preDownloadChapterCount)", value: $config.preDownloadChapterCount, in: 0...50)

            Picker("简繁转换", selection: $config.chineseConvertMode) {
                ForEach(ChineseConvertMode.allCases, id: \.rawValue) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Toggle("内容处理", isOn: $config.processText)
            Toggle("替换规则", isOn: $config.replaceRuleEnabled)
        }
    }

    private var readerDisplaySection: some View {
        Section("阅读显示") {
            Stepper("字号: \(Int(config.fontSize))", value: $config.fontSize, in: 12...36, step: 1)
            Stepper("行距: \(String(format: "%.1f", config.lineSpacing))", value: $config.lineSpacing, in: 0.5...3.0, step: 0.1)
            Stepper("字距: \(String(format: "%.1f", config.letterSpacing))", value: $config.letterSpacing, in: 0.0...5.0, step: 0.5)
            Stepper("段距: \(String(format: "%.0f", config.paragraphSpacing))", value: $config.paragraphSpacing, in: 0...30, step: 2)

            Toggle("两端对齐", isOn: $config.textFullJustify)
            Toggle("中文优化排版", isOn: $config.useZhLayout)
            Toggle("首行缩进", isOn: $config.paragraphIndent)
            Toggle("显示章节标题", isOn: $config.showChapterTitle)
        }
    }

    private var readerBehaviorSection: some View {
        Section("阅读行为") {
            Toggle("保持屏幕常亮", isOn: $config.keepScreenOn)
            Toggle("音量键翻页", isOn: $config.volumeKeyPageTurn)
            Toggle("按页朗读", isOn: $config.readAloudByPage)
            Toggle("目录倒序", isOn: $config.tocReversed)

            Picker("左侧点击", selection: $config.clickActionLeft) {
                ForEach(ClickAction.allCases, id: \.rawValue) { action in
                    Text(action.title).tag(action)
                }
            }

            Picker("中间点击", selection: $config.clickActionMiddle) {
                ForEach(ClickAction.allCases, id: \.rawValue) { action in
                    Text(action.title).tag(action)
                }
            }

            Picker("右侧点击", selection: $config.clickActionRight) {
                ForEach(ClickAction.allCases, id: \.rawValue) { action in
                    Text(action.title).tag(action)
                }
            }

            Stepper("自动翻页间隔: \(Int(config.autoPageTurnInterval))秒", value: $config.autoPageTurnInterval, in: 5...120, step: 5)
        }
    }

    private var cacheSection: some View {
        Section("缓存") {
            Stepper("最大缓存: \(config.maxCacheSize)MB", value: $config.maxCacheSize, in: 50...500, step: 50)
        }
    }

    private var backupSection: some View {
        Section("备份") {
            Toggle("自动备份", isOn: $config.autoBackupEnabled)
            Stepper("备份间隔: \(config.autoBackupInterval)小时", value: $config.autoBackupInterval, in: 1...168, step: 1)
                .disabled(!config.autoBackupEnabled)
        }
    }

    private var syncSection: some View {
        Section("同步") {
            Toggle("WebDAV自动同步", isOn: $config.webDavAutoSync)
            Toggle("仅WiFi下同步", isOn: $config.webDavSyncWifiOnly)
                .disabled(!config.webDavAutoSync)
        }
    }

    private var searchSection: some View {
        Section("搜索") {
            Stepper("并发数: \(config.searchConcurrency)", value: $config.searchConcurrency, in: 1...16)
            Stepper("超时: \(config.searchTimeout)秒", value: $config.searchTimeout, in: 5...60, step: 5)
        }
    }

    private var sourceSection: some View {
        Section("书源") {
            Toggle("自动更新书源", isOn: $config.sourceAutoUpdateEnabled)
            Stepper("更新间隔: \(config.sourceAutoUpdateInterval)小时", value: $config.sourceAutoUpdateInterval, in: 1...168, step: 1)
                .disabled(!config.sourceAutoUpdateEnabled)
        }
    }

    private var resetSection: some View {
        Section {
            Button("恢复默认设置", role: .destructive) {
                showingResetConfirm = true
            }
        }
        .confirmationDialog("确认恢复默认设置？", isPresented: $showingResetConfirm) {
            Button("恢复默认", role: .destructive) {
                config.resetToDefaults()
            }
            Button("取消", role: .cancel) {}
        }
    }
}
