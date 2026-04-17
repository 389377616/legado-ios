import SwiftUI

struct ReaderSettingsFullView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReaderViewModel
    @Binding var isPresented: Bool
    
    @AppStorage("pageAnimation") private var pageAnimation: Int = PageAnimationType.cover.rawValue
    @AppStorage("leftTapRatio") private var leftTapRatio: Double = 0.3
    @AppStorage("rightTapRatio") private var rightTapRatio: Double = 0.3
    @AppStorage("showHeader") private var showHeader: Bool = true
    @AppStorage("showFooter") private var showFooter: Bool = true
    @AppStorage("headerContent") private var headerContent: String = "章节名"
    @AppStorage("footerContent") private var footerContent: String = "进度"
    @AppStorage("textFullJustify") private var textFullJustify: Bool = true
    @AppStorage("useZhLayout") private var useZhLayout: Bool = true
    @AppStorage("paragraphIndent") private var paragraphIndent: Int = 2
    
    private let pageAnimations: [PageAnimationType] = PageAnimationType.allCases
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("翻页动画")) {
                    ForEach(pageAnimations, id: \.self) { animation in
                        Button(action: { pageAnimation = animation.rawValue }) {
                            HStack {
                                Text(animation.title)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if pageAnimation == animation.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("点击区域")) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("左侧区域（上一页）")
                            Spacer()
                            Text("\(Int(leftTapRatio * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $leftTapRatio, in: 0.1...0.5, step: 0.05)
                    }
                    .padding(.vertical, 8)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("右侧区域（下一页）")
                            Spacer()
                            Text("\(Int(rightTapRatio * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $rightTapRatio, in: 0.1...0.5, step: 0.05)
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Text("中间区域")
                        Spacer()
                        Text("\(Int((1 - leftTapRatio - rightTapRatio) * 100))%")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("页眉设置")) {
                    Toggle("显示页眉", isOn: $showHeader)
                    
                    if showHeader {
                        Picker("页眉内容", selection: $headerContent) {
                            Text("章节名").tag("章节名")
                            Text("书名").tag("书名")
                            Text("书名+章节").tag("书名+章节")
                            Text("时间").tag("时间")
                            Text("自定义").tag("自定义")
                        }
                    }
                }
                
                Section(header: Text("页脚设置")) {
                    Toggle("显示页脚", isOn: $showFooter)
                    
                    if showFooter {
                        Picker("页脚内容", selection: $footerContent) {
                            Text("进度").tag("进度")
                            Text("页码").tag("页码")
                            Text("时间").tag("时间")
                            Text("章节进度").tag("章节进度")
                            Text("自定义").tag("自定义")
                        }
                    }
                }
                
                Section(header: Text("排版设置")) {
                    Toggle("两端对齐", isOn: $textFullJustify)
                    Toggle("中文排版优化", isOn: $useZhLayout)
                    
                    Stepper("首行缩进：\(paragraphIndent) 字", value: $paragraphIndent, in: 0...4)
                }
                
                Section(header: Text("阅读体验")) {
                    NavigationLink(destination: FontSettingsView(viewModel: viewModel, isPresented: $isPresented)) {
                        Text("字体设置")
                    }
                    
                    NavigationLink(destination: ReaderThemeSettingsView(viewModel: viewModel, isPresented: $isPresented)) {
                        Text("主题设置")
                    }
                    
                    NavigationLink(destination: CoverConfigView()) {
                        Text("封面设置")
                    }
                    
                    NavigationLink(destination: ReplaceRuleView()) {
                        Text("替换规则")
                    }
                    
                    NavigationLink(destination: TxtTocRuleView()) {
                        Text("目录规则")
                    }
                }
                
                Section(header: Text("高级设置")) {
                    NavigationLink(destination: HttpTTSConfigView()) {
                        Text("TTS设置")
                    }
                    
                    NavigationLink(destination: DictRuleView()) {
                        Text("字典规则")
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        Text("关于")
                    }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct ReaderThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReaderViewModel
    @Binding var isPresented: Bool
    
    @State private var customBackgroundColor: Color = .white
    @State private var customTextColor: Color = .black
    @State private var showingBackgroundPicker = false
    @State private var customBackgroundImage: UIImage?
    
    private let presetThemes: [(name: String, background: Color, text: Color)] = [
        ("亮色", .white, .black),
        ("暗色", .black, .white),
        ("羊皮纸", Color(red: 0.96, green: 0.91, blue: 0.83), Color(red: 0.33, green: 0.28, blue: 0.22)),
        ("护眼", Color(red: 0.75, green: 0.84, blue: 0.71), .black),
        ("微信读书", Color(red: 0.75, green: 0.93, blue: 0.78), .black),
        ("淡紫", Color(red: 0.86, green: 0.73, blue: 0.89), .black),
        ("浅蓝", Color(red: 0.67, green: 0.81, blue: 0.88), .black)
    ]
    
    var body: some View {
        List {
            Section(header: Text("预设主题")) {
                ForEach(presetThemes, id: \.name) { theme in
                    Button(action: {
                        viewModel.backgroundColor = theme.background
                        viewModel.textColor = theme.text
                        viewModel.applyTheme(themeFromColors(theme.background, theme.text))
                    }) {
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.background)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text("文")
                                        .foregroundColor(theme.text)
                                        .font(.system(size: 14))
                                )
                            
                            Text(theme.name)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if viewModel.backgroundColor == theme.background {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("自定义颜色")) {
                ColorPicker("背景色", selection: $customBackgroundColor, supportsOpacity: false)
                ColorPicker("文字色", selection: $customTextColor, supportsOpacity: false)
                
                Button("应用自定义颜色") {
                    viewModel.backgroundColor = customBackgroundColor
                    viewModel.textColor = customTextColor
                }
            }
            
            Section(header: Text("自定义背景图")) {
                Button(action: { showingBackgroundPicker = true }) {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                        Text("选择背景图")
                    }
                }
                
                if let image = customBackgroundImage {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(4)
                        
                        Button("清除背景图") {
                            customBackgroundImage = nil
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            Section(header: Text("预览")) {
                Text("这是主题预览文本，用于展示当前主题效果。阅读是一种美好的体验，让我们享受文字带来的乐趣。")
                    .padding()
                    .background(
                        Group {
                            if let image = customBackgroundImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                viewModel.backgroundColor
                            }
                        }
                    )
                    .foregroundColor(viewModel.textColor)
            }
        }
        .navigationTitle("主题设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingBackgroundPicker) {
            ImagePicker(image: $customBackgroundImage)
        }
    }
    
    private func themeFromColors(_ background: Color, _ text: Color) -> ReaderViewModel.ReaderTheme {
        if background == .white { return .light }
        if background == .black { return .dark }
        if background == Color(red: 0.96, green: 0.91, blue: 0.83) { return .sepia }
        return .eyeProtection
    }
}

#Preview {
    ReaderSettingsFullView(
        viewModel: ReaderViewModel(),
        isPresented: .constant(true)
    )
}