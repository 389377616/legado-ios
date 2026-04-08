import SwiftUI

struct CodeEditView: View {
    let initialCode: String
    let title: String
    let onSave: ((String) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var code: String
    @State private var showFormat = false
    @State private var cursorPosition: Int = 0
    
    init(initialCode: String = "", title: String = "代码编辑", onSave: ((String) -> Void)? = nil) {
        self.initialCode = initialCode
        self.title = title
        self.onSave = onSave
        _code = State(initialValue: initialCode)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                toolbar
                editor
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave?(code)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showFormat) {
                FormatHelpView()
            }
        }
    }
    
    private var toolbar: some View {
        HStack(spacing: 16) {
            Button(action: { code = "" }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            
            Button(action: { formatCode() }) {
                Image(systemName: "text.alignleft")
            }
            
            Button(action: { showFormat = true }) {
                Image(systemName: "questionmark.circle")
            }
            
            Spacer()
            
            Text("\(code.count) 字符")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    private var editor: some View {
        TextEditor(text: $code)
            .font(.system(.body, design: .monospaced))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
    }
    
    private func formatCode() {
        var formatted = code
        
        formatted = formatted.replacingOccurrences(of: "\n\\s*\n\\s*\n", with: "\n\n", options: .regularExpression)
        
        formatted = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        
        code = formatted
    }
}

struct FormatHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("规则语法") {
                    HelpRow(title: "@get:{xpath}", description: "XPath选择器")
                    HelpRow(title: "@css:{selector}", description: "CSS选择器")
                    HelpRow(title: "@json:{path}", description: "JSON路径")
                    HelpRow(title: "@js:{script}", description: "JavaScript脚本")
                    HelpRow(title: "@regex:{pattern}", description: "正则表达式")
                }
                
                Section("XPath示例") {
                    CodeExample(code: "//div[@class='title']/text()")
                    CodeExample(code: "//a/@href")
                    CodeExample(code: "//p[contains(@class,'content')]")
                }
                
                Section("JSON示例") {
                    CodeExample(code: "$.data.list[*].name")
                    CodeExample(code: "$..bookList[0].bookName")
                }
                
                Section("JavaScript示例") {
                    CodeExample(code: "result = JSON.parse(result);")
                    CodeExample(code: "result.map(item => item.name).join(',');")
                }
            }
            .navigationTitle("格式帮助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct HelpRow: View {
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CodeExample: View {
    let code: String
    
    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(4)
    }
}