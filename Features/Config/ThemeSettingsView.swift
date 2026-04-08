import SwiftUI

struct ThemeSettingsView: View {
    @AppStorage("app_theme") private var selectedTheme = "system"
    @AppStorage("reader.background_color") private var backgroundColorData = Data()
    @AppStorage("reader.text_color") private var textColorData = Data()
    
    @State private var customBackgroundColor = Color.white
    @State private var customTextColor = Color.black
    
    var body: some View {
        List {
            Section("外观模式") {
                ForEach([
                    ("system", "跟随系统", "iphone"),
                    ("light", "浅色模式", "sun.max"),
                    ("dark", "深色模式", "moon")
                ], id: \.0) { (value, label, icon) in
                    Button(action: { selectedTheme = value }) {
                        HStack {
                            Image(systemName: icon)
                                .frame(width: 24)
                                .foregroundColor(.blue)
                            Text(label)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedTheme == value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Section("阅读背景预设") {
                ForEach([
                    ("白色", Color.white),
                    ("米黄", Color(red: 0.98, green: 0.95, blue: 0.88)),
                    ("浅绿", Color(red: 0.8, green: 0.93, blue: 0.8)),
                    ("浅灰", Color(white: 0.95)),
                    ("深灰", Color(white: 0.2)),
                    ("深褐", Color(red: 0.15, green: 0.12, blue: 0.1))
                ], id: \.0) { (name, color) in
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .frame(width: 40, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        Text(name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        saveColors(background: color, text: color.isDark ? .white : .black)
                    }
                }
            }
            
            Section("自定义颜色") {
                ColorPicker("背景颜色", selection: $customBackgroundColor)
                    .onChange(of: customBackgroundColor) { _ in
                        saveColors(background: customBackgroundColor, text: customTextColor)
                    }
                
                ColorPicker("文字颜色", selection: $customTextColor)
                    .onChange(of: customTextColor) { _ in
                        saveColors(background: customBackgroundColor, text: customTextColor)
                    }
            }
            
            Section("说明") {
                Text("阅读背景设置会在阅读器中生效。深色主题会同时影响应用整体外观。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("主题")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadColors()
        }
    }
    
    private func saveColors(background: Color, text: Color) {
        backgroundColorData = UIColor(background).encode()
        textColorData = UIColor(text).encode()
    }
    
    private func loadColors() {
        if let bg = UIColor.decode(from: backgroundColorData) {
            customBackgroundColor = Color(bg)
        }
        if let fg = UIColor.decode(from: textColorData) {
            customTextColor = Color(fg)
        }
    }
}

extension Color {
    var isDark: Bool {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance < 0.5
    }
}

extension UIColor {
    func encode() -> Data {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Data([UInt8(red * 255), UInt8(green * 255), UInt8(blue * 255), UInt8(alpha * 255)])
    }
    
    static func decode(from data: Data) -> UIColor? {
        guard data.count == 4 else { return nil }
        return UIColor(
            red: CGFloat(data[0]) / 255,
            green: CGFloat(data[1]) / 255,
            blue: CGFloat(data[2]) / 255,
            alpha: CGFloat(data[3]) / 255
        )
    }
}