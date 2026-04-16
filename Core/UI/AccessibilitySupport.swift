import SwiftUI
import UIKit

struct AccessibilityModifier: ViewModifier {
    let label: String?
    let hint: String?
    let traits: AccessibilityTraits?
    let value: String?

    init(label: String? = nil, hint: String? = nil, traits: AccessibilityTraits? = nil, value: String? = nil) {
        self.label = label
        self.hint = hint
        self.traits = traits
        self.value = value
    }

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .applyIf(let: label) { view, label in
                view.accessibilityLabel(label)
            }
            .applyIf(let: hint) { view, hint in
                view.accessibilityHint(hint)
            }
            .applyIf(let: traits) { view, traits in
                view.accessibilityAddTraits(traits)
            }
            .applyIf(let: value) { view, value in
                view.accessibilityValue(value)
            }
    }
}

extension View {
    func legadoAccessibility(label: String? = nil, hint: String? = nil, traits: AccessibilityTraits? = nil, value: String? = nil) -> some View {
        modifier(AccessibilityModifier(label: label, hint: hint, traits: traits, value: value))
    }

    func bookAccessibility(_ book: Book) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(book.name)，\(book.author.isEmpty ? "未知作者" : book.author)")
            .accessibilityValue(book.readProgressText)
            .accessibilityHint("双击打开阅读")
            .accessibilityAddTraits(.isButton)
    }

    func chapterAccessibility(title: String, index: Int, isRead: Bool) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("第\(index + 1)章 \(title)")
            .accessibilityValue(isRead ? "已读" : "未读")
            .accessibilityHint("双击跳转到此章节")
            .accessibilityAddTraits(.isButton)
    }

    func readerPageAccessibility(chapterTitle: String, pageIndex: Int, totalPages: Int) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(chapterTitle)，第\(pageIndex + 1)页，共\(totalPages)页")
            .accessibilityHint("左右滑动翻页")
    }

    func dynamicTypeScaled(baseSize: CGFloat, maxSize: CGFloat = 28) -> some View {
        let scaledSize = UIFontMetrics.default.scaledValue(for: baseSize)
        let clampedSize = min(scaledSize, maxSize)
        return self.font(.system(size: clampedSize))
    }
}

extension View {
    func applyIf<T>(let value: T?, transform: (Self, T) -> Self) -> Self {
        if let value = value {
            return transform(self, value)
        }
        return self
    }
}

struct AccessibleBookGridCell: View {
    let book: Book
    let showUnread: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                BookCoverView(url: book.displayCoverUrl, sourceId: book.customCoverUrl == nil ? book.source?.sourceId : nil)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)

                if showUnread && book.hasNewChapter {
                    Text("新")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: -4, y: 4)
                        .accessibilityLabel("有新章节")
                }
            }

            Text(book.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .frame(height: 32)
                .dynamicTypeScaled(baseSize: 12, maxSize: 20)
        }
        .contentShape(Rectangle())
        .bookAccessibility(book)
    }
}

struct AccessibleBookListCell: View {
    let book: Book
    let showUnread: Bool
    let showUpdateTime: Bool

    var body: some View {
        HStack(spacing: 10) {
            BookCoverView(url: book.displayCoverUrl, sourceId: book.customCoverUrl == nil ? book.source?.sourceId : nil)
                .frame(width: 66, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(book.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .dynamicTypeScaled(baseSize: 17, maxSize: 26)

                    Spacer()

                    if showUnread && book.hasNewChapter {
                        Text("新")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .accessibilityLabel("有新章节")
                    }
                }

                HStack(spacing: 2) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)

                    Text(book.author.isEmpty ? "未知" : book.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .dynamicTypeScaled(baseSize: 12, maxSize: 18)
                }
                .accessibilityLabel("作者: \(book.author.isEmpty ? "未知" : book.author)")

                Text(book.readProgressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .dynamicTypeScaled(baseSize: 12, maxSize: 18)
                    .accessibilityLabel("阅读进度: \(book.readProgressText)")

                if let latestChapter = book.latestChapterTitle, !latestChapter.isEmpty {
                    Text(latestChapter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .dynamicTypeScaled(baseSize: 12, maxSize: 18)
                        .accessibilityLabel("最新章节: \(latestChapter)")
                }

                Spacer()
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .bookAccessibility(book)
    }
}

struct AccessibleReaderControls: View {
    let chapterTitle: String
    let pageIndex: Int
    let totalPages: Int
    let onPreviousPage: () -> Void
    let onNextPage: () -> Void
    let onToggleMenu: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPreviousPage) {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityLabel("上一页")
            .accessibilityHint("翻到上一页")

            Button(action: onToggleMenu) {
                Color.clear.frame(width: 100, height: 100)
            }
            .accessibilityLabel("阅读菜单")
            .accessibilityHint("双击打开阅读菜单")

            Button(action: onNextPage) {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityLabel("下一页")
            .accessibilityHint("翻到下一页")
        }
        .readerPageAccessibility(chapterTitle: chapterTitle, pageIndex: pageIndex, totalPages: totalPages)
    }
}

struct AccessibilitySettingsView: View {
    @AppStorage("accessibility.highContrast") private var highContrast = false
    @AppStorage("accessibility.reduceMotion") private var reduceMotion = false
    @AppStorage("accessibility.largeCursor") private var largeCursor = false
    @AppStorage("accessibility.boldText") private var boldText = false

    var body: some View {
        List {
            Section("显示增强") {
                Toggle("高对比度模式", isOn: $highContrast)
                Toggle("加粗文字", isOn: $boldText)
                Toggle("大光标", isOn: $largeCursor)
            }

            Section("动画") {
                Toggle("减少动画", isOn: $reduceMotion)
            }

            Section("系统辅助功能") {
                NavigationLink("系统辅助功能设置") {
                    SystemAccessibilityView()
                }
            }

            Section("说明") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Legado iOS 支持以下辅助功能：")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    accessibilityFeatureList
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("无障碍设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var accessibilityFeatureList: some View {
        VStack(alignment: .leading, spacing: 6) {
            FeatureItem(icon: "textformat.size", text: "Dynamic Type 自适应字体")
            FeatureItem(icon: "speaker.wave.2", text: "VoiceOver 屏幕朗读")
            FeatureItem(icon: "hand.draw", text: "VoiceControl 语音控制")
            FeatureItem(icon: "switch.2", text: "Switch Control 开关控制")
            FeatureItem(icon: "eye", text: "高对比度模式")
            FeatureItem(icon: "move.3d", text: "减少动画选项")
        }
    }
}

struct SystemAccessibilityView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "accessibility")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("系统辅助功能")
                .font(.title2)
                .fontWeight(.semibold)

            Text("请在系统设置中配置辅助功能")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("打开系统设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("系统辅助功能")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.blue)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
