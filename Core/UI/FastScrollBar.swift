import SwiftUI

struct FastScrollBar: View {
    let totalItems: Int
    @Binding var scrollOffset: CGFloat
    let itemHeight: CGFloat
    let visibleHeight: CGFloat
    let onScrollToIndex: (Int) -> Void

    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @State private var indicatorText: String = ""

    private var trackHeight: CGFloat {
        max(visibleHeight - 40, 100)
    }

    private var thumbHeight: CGFloat {
        guard totalItems > 0 else { return 30 }
        let ratio = min(visibleHeight / (CGFloat(totalItems) * itemHeight), 1.0)
        return max(30, trackHeight * ratio)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                trackView

                thumbView
                    .offset(y: thumbPosition(in: geo.size.height))
                    .gesture(dragGesture(in: geo.size.height))
            }
            .frame(width: 20)
            .padding(.trailing, 2)
        }
        .frame(width: 24)
        .opacity(isDragging ? 1.0 : 0.4)
        .overlay(alignment: .trailing) {
            if isDragging && !indicatorText.isEmpty {
                indicatorBubble
                    .offset(x: -32, y: thumbPosition(in: trackHeight) + thumbHeight / 2 - 20)
            }
        }
    }

    private var trackView: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(.systemGray4))
            .frame(width: 4)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 8)
    }

    private var thumbView: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(isDragging ? Color.accentColor : Color(.systemGray2))
            .frame(width: isDragging ? 20 : 12, height: thumbHeight)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
    }

    private var indicatorBubble: some View {
        Text(indicatorText)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 4)
            .transition(.opacity)
    }

    private func thumbPosition(in height: CGFloat) -> CGFloat {
        guard totalItems > 0 else { return 0 }
        let maxOffset = height - thumbHeight
        let ratio = min(max(scrollOffset / (CGFloat(totalItems) * itemHeight - visibleHeight), 0), 1)
        return ratio * maxOffset
    }

    private func dragGesture(in height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let maxOffset = height - thumbHeight
                let clampedY = min(max(value.location.y - thumbHeight / 2, 0), maxOffset)
                let ratio = clampedY / maxOffset
                let targetOffset = ratio * (CGFloat(totalItems) * itemHeight - visibleHeight)
                scrollOffset = targetOffset

                let targetIndex = Int(ratio * CGFloat(totalItems))
                let clampedIndex = min(max(targetIndex, 0), totalItems - 1)
                indicatorText = "\(clampedIndex + 1)/\(totalItems)"
                onScrollToIndex(clampedIndex)
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    isDragging = false
                }
                indicatorText = ""
            }
    }
}

struct FastScrollView<Content: View>: View {
    let content: Content
    let itemCount: Int
    let itemHeight: CGFloat

    @State private var scrollOffset: CGFloat = 0
    @State private var showScrollBar = false

    init(itemCount: Int, itemHeight: CGFloat = 80, @ViewBuilder content: () -> Content) {
        self.itemCount = itemCount
        self.itemHeight = itemHeight
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        content
                            .background(
                                ScrollOffsetReader()
                            )
                    }
                    .coordinateSpace(name: "fastScrollView")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = -value
                        showScrollBar = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            showScrollBar = false
                        }
                    }

                    FastScrollBar(
                        totalItems: itemCount,
                        scrollOffset: $scrollOffset,
                        itemHeight: itemHeight,
                        visibleHeight: geo.size.height,
                        onScrollToIndex: { index in
                            proxy.scrollTo(index, anchor: .top)
                        }
                    )
                }
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetReader: View {
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geo.frame(in: .named("fastScrollView")).minY
                )
        }
        .frame(height: 0)
    }
}

struct ChapterFastScrollBar: View {
    let chapters: [BookChapter]
    @Binding var currentChapterIndex: Int
    let onScrollToChapter: (Int) -> Void

    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var indicatorText: String {
        guard !chapters.isEmpty else { return "" }
        let index = Int(dragProgress * Double(chapters.count - 1))
        let clamped = min(max(index, 0), chapters.count - 1)
        return chapters[clamped].title ?? "第\(clamped + 1)章"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 0) {
                Spacer()

                if isDragging {
                    chapterIndicator
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }

                chapterTrack
                    .gesture(dragGesture)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private var chapterIndicator: some View {
        Text(indicatorText)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.systemGray))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 6)
            .padding(.trailing, 16)
    }

    private var chapterTrack: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isDragging ? Color.accentColor.opacity(0.6) : Color(.systemGray3))
            .frame(width: isDragging ? 8 : 4)
            .padding(.trailing, 4)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let progress = min(max(Double(value.location.y / 300), 0), 1)
                dragProgress = progress
                let index = Int(progress * Double(chapters.count - 1))
                let clamped = min(max(index, 0), chapters.count - 1)
                onScrollToChapter(clamped)
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    isDragging = false
                }
            }
    }
}
