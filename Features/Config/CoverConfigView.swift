import SwiftUI

struct CoverConfigView: View {
    @AppStorage("cover.showName") private var showName = true
    @AppStorage("cover.showAuthor") private var showAuthor = true
    @AppStorage("cover.showProgress") private var showProgress = true
    @AppStorage("cover.cornerRadius") private var cornerRadius = 4.0
    @AppStorage("cover.shadowEnabled") private var shadowEnabled = true
    @AppStorage("cover.defaultCover") private var defaultCoverType = "gradient"
    
    var body: some View {
        List {
            Section("显示选项") {
                Toggle("显示书名", isOn: $showName)
                Toggle("显示作者", isOn: $showAuthor)
                Toggle("显示阅读进度", isOn: $showProgress)
            }
            
            Section("样式") {
                VStack(alignment: .leading) {
                    Text("圆角大小: \(Int(cornerRadius))")
                    Slider(value: $cornerRadius, in: 0...16, step: 1)
                }
                
                Toggle("显示阴影", isOn: $shadowEnabled)
            }
            
            Section("默认封面样式") {
                ForEach([
                    ("gradient", "渐变色", "square.on.square"),
                    ("pattern", "图案", "square.grid.3x3"),
                    ("solid", "纯色", "square.fill"),
                    ("icon", "图标", "book")
                ], id: \.0) { (value, label, icon) in
                    Button(action: { defaultCoverType = value }) {
                        HStack {
                            Image(systemName: icon)
                                .frame(width: 24)
                            Text(label)
                                .foregroundColor(.primary)
                            Spacer()
                            if defaultCoverType == value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section("预览") {
                CoverPreviewCard(
                    title: "示例书籍",
                    author: "作者名",
                    progress: 0.65,
                    showName: showName,
                    showAuthor: showAuthor,
                    showProgress: showProgress,
                    cornerRadius: cornerRadius,
                    shadowEnabled: shadowEnabled,
                    coverType: defaultCoverType
                )
                .frame(width: 100, height: 140)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("封面设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CoverPreviewCard: View {
    let title: String
    let author: String
    let progress: Double
    let showName: Bool
    let showAuthor: Bool
    let showProgress: Bool
    let cornerRadius: Double
    let shadowEnabled: Bool
    let coverType: String
    
    var body: some View {
        ZStack {
            coverBackground
            
            VStack {
                Spacer()
                
                if showProgress {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geo.size.width * progress, height: 3)
                    }
                    .frame(height: 3)
                }
            }
        }
        .cornerRadius(cornerRadius)
        .shadow(color: shadowEnabled ? Color.black.opacity(0.2) : .clear, radius: 3, x: 0, y: 2)
        .overlay(
            VStack {
                Spacer()
                if showName || showAuthor {
                    VStack(spacing: 2) {
                        if showName {
                            Text(title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        if showAuthor {
                            Text(author)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.5))
                }
            }
            .cornerRadius(cornerRadius, corners: [.bottomLeft, .bottomRight])
        )
    }
    
    @ViewBuilder
    var coverBackground: some View {
        switch coverType {
        case "gradient":
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "pattern":
            Color.gray.opacity(0.3)
                .overlay(
                    Image(systemName: "books.vertical.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.5))
                )
        case "solid":
            Color.blue.opacity(0.8)
        case "icon":
            Color.orange.opacity(0.3)
                .overlay(
                    Image(systemName: "book.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                )
        default:
            Color.gray
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let tl = CGPoint(x: rect.minX, y: rect.minY)
        let tr = CGPoint(x: rect.maxX, y: rect.minY)
        let bl = CGPoint(x: rect.minX, y: rect.maxY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY)
        
        if corners.contains(.topLeft) {
            path.move(to: CGPoint(x: tl.x + radius, y: tl.y))
        } else {
            path.move(to: tl)
        }
        
        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: tr.x - radius, y: tr.y))
            path.addArc(center: CGPoint(x: tr.x - radius, y: tr.y + radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        } else {
            path.addLine(to: tr)
        }
        
        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: br.x, y: br.y - radius))
            path.addArc(center: CGPoint(x: br.x - radius, y: br.y - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        } else {
            path.addLine(to: br)
        }
        
        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: bl.x + radius, y: bl.y))
            path.addArc(center: CGPoint(x: bl.x + radius, y: bl.y - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        } else {
            path.addLine(to: bl)
        }
        
        if corners.contains(.topLeft) {
            path.addLine(to: CGPoint(x: tl.x, y: tl.y + radius))
            path.addArc(center: CGPoint(x: tl.x + radius, y: tl.y + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            path.addLine(to: tl)
        }
        
        return path
    }
}