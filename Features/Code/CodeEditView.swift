import SwiftUI
import UIKit

struct CodeEditView: View {
    let initialCode: String
    let title: String
    let language: CodeLanguage
    let onSave: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var code: String
    @State private var showFormat = false
    @State private var showFindReplace = false
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var showSnippets = false
    @State private var undoManager = CodeUndoManager()

    init(initialCode: String = "", title: String = "代码编辑", language: CodeLanguage = .rule, onSave: ((String) -> Void)? = nil) {
        self.initialCode = initialCode
        self.title = title
        self.language = language
        self.onSave = onSave
        _code = State(initialValue: initialCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if showFindReplace { findReplaceBar }
            CodeEditorRepresentable(
                code: $code,
                language: language,
                undoManager: undoManager
            )
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
            FormatHelpView(language: language)
        }
        .sheet(isPresented: $showSnippets) {
            CodeSnippetsView(language: language) { snippet in
                code += snippet
                showSnippets = false
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: { undoManager.undo() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!undoManager.canUndo)

            Button(action: { undoManager.redo() }) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!undoManager.canRedo)

            Divider().frame(height: 20)

            Button(action: { withAnimation { showFindReplace.toggle() } }) {
                Image(systemName: "magnifyingglass")
            }

            Button(action: { formatCode() }) {
                Image(systemName: "text.alignleft")
            }

            Button(action: { showSnippets = true }) {
                Image(systemName: "text.badge.plus")
            }

            Button(action: { showFormat = true }) {
                Image(systemName: "questionmark.circle")
            }

            Spacer()

            Text("\(code.count) 字符")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    private var findReplaceBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("查找", text: $findText)
                    .textFieldStyle(.roundedBorder)
                Text("\(countOccurrences(of: findText))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .foregroundColor(.secondary)
                TextField("替换", text: $replaceText)
                    .textFieldStyle(.roundedBorder)
                Button("替换") {
                    replaceFirst(of: findText, with: replaceText)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("全部") {
                    replaceAll(of: findText, with: replaceText)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func formatCode() {
        undoManager.record(code)
        var formatted = code
        formatted = formatted.replacingOccurrences(of: "\n\\s*\n\\s*\n", with: "\n\n", options: .regularExpression)
        formatted = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        code = formatted
    }

    private func countOccurrences(of text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return code.components(separatedBy: text).count - 1
    }

    private func replaceFirst(of target: String, with replacement: String) {
        guard !target.isEmpty, let range = code.range(of: target) else { return }
        undoManager.record(code)
        code.replaceSubrange(range, with: replacement)
    }

    private func replaceAll(of target: String, with replacement: String) {
        guard !target.isEmpty else { return }
        undoManager.record(code)
        code = code.replacingOccurrences(of: target, with: replacement)
    }
}

struct CodeEditorRepresentable: UIViewRepresentable {
    @Binding var code: String
    let language: CodeLanguage
    let undoManager: CodeUndoManager

    func makeUIView(context: Context) -> CodeTextView {
        let textView = CodeTextView()
        textView.delegate = context.coordinator
        textView.language = language
        textView.text = code
        textView.undoManagerRef = undoManager
        return textView
    }

    func updateUIView(_ textView: CodeTextView, context: Context) {
        if textView.text != code {
            textView.text = code
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(code: $code)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var code: Binding<String>

        init(code: Binding<String>) {
            self.code = code
        }

        func textViewDidChange(_ textView: UITextView) {
            code.wrappedValue = textView.text ?? ""
            if let codeTextView = textView as? CodeTextView {
                codeTextView.highlightSyntax()
            }
        }
    }
}

class CodeTextView: UITextView {
    var language: CodeLanguage = .rule
    var undoManagerRef: CodeUndoManager?

    private let lineNumberView = LineNumberView()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        let container = NSTextContainer()
        container.widthTracksTextView = true
        let storage = SyntaxHighlightTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)

        super.init(frame: frame, textContainer: container)

        font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        backgroundColor = .systemBackground
        textColor = .label
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        textContainerInset = UIEdgeInsets(top: 8, left: 44, bottom: 8, right: 8)

        addSubview(lineNumberView)
        setupLineNumberView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setupLineNumberView()
        highlightSyntax()
    }

    private func setupLineNumberView() {
        lineNumberView.frame = CGRect(x: 0, y: 0, width: 40, height: contentSize.height)
        lineNumberView.lineCount = numberOfLines
        lineNumberView.contentOffset = contentOffset
    }

    private var numberOfLines: Int {
        guard let text = text, !text.isEmpty else { return 1 }
        return text.components(separatedBy: .newlines).count
    }

    func highlightSyntax() {
        guard let storage = textStorage as? SyntaxHighlightTextStorage else { return }
        storage.highlightSyntax(language: language, in: NSRange(location: 0, length: text.count))
        setupLineNumberView()
    }

    @objc override func keyCommands() -> [UIKeyCommand]? {
        return [
            UIKeyCommand(input: "z", modifierFlags: .command, action: #selector(handleUndo)),
            UIKeyCommand(input: "z", modifierFlags: [.command, .shift], action: #selector(handleRedo)),
        ]
    }

    @objc private func handleUndo() {
        if let previous = undoManagerRef?.undo() {
            text = previous
        }
    }

    @objc private func handleRedo() {
        if let next = undoManagerRef?.redo() {
            text = next
        }
    }
}

class LineNumberView: UIView {
    var lineCount: Int = 1 {
        didSet { setNeedsDisplay() }
    }
    var contentOffset: CGPoint = .zero {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel,
        ]

        let lineHeight: CGFloat = 20
        for i in 0..<lineCount {
            let y = CGFloat(i) * lineHeight - contentOffset.y + 12
            guard y > -lineHeight && y < bounds.height + lineHeight else { continue }
            let numStr = "\(i + 1)" as NSString
            let size = numStr.size(withAttributes: attributes)
            numStr.draw(at: CGPoint(x: 36 - size.width, y: y), withAttributes: attributes)
        }

        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: 40, y: 0))
        context.addLine(to: CGPoint(x: 40, y: bounds.height))
        context.strokePath()
    }
}

class SyntaxHighlightTextStorage: NSTextStorage {
    private let backingStore = NSMutableAttributedString()

    override var string: String {
        return backingStore.string
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    func highlightSyntax(language: CodeLanguage, in range: NSRange) {
        let fullRange = NSRange(location: 0, length: backingStore.length)
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.label,
        ]
        beginEditing()
        backingStore.setAttributes(defaultAttrs, range: fullRange)

        let text = backingStore.string as NSString

        let patterns: [(String, UIColor)] = syntaxPatterns(for: language)
        for (pattern, color) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let matches = regex.matches(in: backingStore.string, options: [], range: fullRange)
            for match in matches {
                backingStore.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        edited(.editedAttributes, range: fullRange, changeInLength: 0)
        endEditing()
    }

    private func syntaxPatterns(for language: CodeLanguage) -> [(String, UIColor)] {
        switch language {
        case .rule:
            return [
                ("@get:\\{[^}]*\\}", UIColor.systemBlue),
                ("@css:\\{[^}]*\\}", UIColor.systemGreen),
                ("@json:\\{[^}]*\\}", UIColor.systemOrange),
                ("@js:\\{[^}]*\\}", UIColor.systemPurple),
                ("@regex:\\{[^}]*\\}", UIColor.systemRed),
                ("@xpath:\\{[^}]*\\}", UIColor.systemTeal),
                ("##[^\\n]*", UIColor.secondaryLabel),
                ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", UIColor.systemBrown),
                ("\\b(true|false|null|undefined)\\b", UIColor.systemRed),
                ("\\b\\d+\\.?\\d*\\b", UIColor.systemOrange),
            ]
        case .javascript:
            return [
                ("//[^\\n]*", UIColor.secondaryLabel),
                ("/\\*[\\s\\S]*?\\*/", UIColor.secondaryLabel),
                ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", UIColor.systemBrown),
                ("'[^'\\\\]*(\\\\.[^'\\\\]*)*'", UIColor.systemBrown),
                ("`[^`]*`", UIColor.systemBrown),
                ("\\b(var|let|const|function|return|if|else|for|while|do|switch|case|break|continue|new|this|typeof|instanceof|try|catch|finally|throw|class|extends|import|export|from|default|async|await|yield)\\b", UIColor.systemPurple),
                ("\\b(true|false|null|undefined|NaN|Infinity)\\b", UIColor.systemRed),
                ("\\b\\d+\\.?\\d*\\b", UIColor.systemOrange),
                ("\\b(console|document|window|JSON|Math|Array|Object|String|Number|Boolean|Date|RegExp|Error|Map|Set|Promise)\\b", UIColor.systemTeal),
            ]
        case .json:
            return [
                ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"\\s*:", UIColor.systemBlue),
                ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", UIColor.systemBrown),
                ("\\b(true|false|null)\\b", UIColor.systemRed),
                ("\\b-?\\d+\\.?\\d*([eE][+-]?\\d+)?\\b", UIColor.systemOrange),
            ]
        case .css:
            return [
                ("/\\*[\\s\\S]*?\\*/", UIColor.secondaryLabel),
                ("\\.[a-zA-Z_-][a-zA-Z0-9_-]*", UIColor.systemGreen),
                ("#[a-zA-Z0-9_-]+", UIColor.systemTeal),
                ("\\b\\d+(px|em|rem|%|vh|vw|s|ms)?\\b", UIColor.systemOrange),
                ("\\b(color|background|font|margin|padding|border|display|position|width|height|top|left|right|bottom|flex|grid|text-align|line-height|overflow)\\b", UIColor.systemPurple),
            ]
        }
    }
}

enum CodeLanguage: String, CaseIterable {
    case rule = "规则"
    case javascript = "JavaScript"
    case json = "JSON"
    case css = "CSS"
}

class CodeUndoManager {
    private var undoStack: [String] = []
    private var redoStack: [String] = []
    private let maxStackSize = 50

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func record(_ state: String) {
        undoStack.append(state)
        if undoStack.count > maxStackSize { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() -> String? {
        guard let state = undoStack.popLast() else { return nil }
        redoStack.append(state)
        return undoStack.last
    }

    func redo() -> String? {
        guard let state = redoStack.popLast() else { return nil }
        undoStack.append(state)
        return state
    }
}

struct FormatHelpView: View {
    let language: CodeLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("规则语法") {
                    HelpRow(title: "@get:{key}", description: "获取变量")
                    HelpRow(title: "@css:{selector}", description: "CSS选择器")
                    HelpRow(title: "@json:{path}", description: "JSON路径")
                    HelpRow(title: "@js:{script}", description: "JavaScript脚本")
                    HelpRow(title: "@regex:{pattern}", description: "正则表达式")
                    HelpRow(title: "@xpath:{expr}", description: "XPath表达式")
                    HelpRow(title: "@class:{className}", description: "类名过滤")
                }

                Section("特殊变量") {
                    HelpRow(title: "{{result}}", description: "上一规则结果")
                    HelpRow(title: "{{baseUrl}}", description: "当前页面URL")
                    HelpRow(title: "{{book}}", description: "书籍对象")
                    HelpRow(title: "{{source}}", description: "书源对象")
                    HelpRow(title: "{{chapter}}", description: "章节对象")
                }

                Section("CSS示例") {
                    CodeExample(code: "div.title")
                    CodeExample(code: "a[href]@attr:href")
                    CodeExample(code: "img.cover@attr:src")
                    CodeExample(code: "p.content@text")
                    CodeExample(code: "li:nth-child(2)")
                }

                Section("JSON示例") {
                    CodeExample(code: "$.data.list[*].name")
                    CodeExample(code: "$..bookList[0].bookName")
                    CodeExample(code: "$.result.list[?(@.type==1)]")
                }

                Section("JavaScript示例") {
                    CodeExample(code: "result = JSON.parse(result);")
                    CodeExample(code: "result.map(item => item.name).join('\\n');")
                    CodeExample(code: "java.ajax(url).body;")
                }

                Section("正则示例") {
                    CodeExample(code: "##<[^>]+>")
                    CodeExample(code: "##^\\s+|\\s+$")
                    CodeExample(code: "##(\\d+)章")
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

struct CodeSnippetsView: View {
    let language: CodeLanguage
    let onInsert: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var snippets: [(String, String)] {
        switch language {
        case .rule:
            return [
                ("CSS选择器", "@css:{div.content@text}"),
                ("JSON路径", "@json:{$.data.list}"),
                ("JS脚本", "@js:{\nresult = JSON.parse(result);\nresult.map(item => item.name).join('\\n');\n}"),
                ("正则替换", "@regex:{##<[^>]+>}"),
                ("XPath", "@xpath:{//div[@class='title']/text()}"),
                ("获取属性", "@css:{a@attr:href}"),
                ("获取文本", "@css:{div.text@textNodes}"),
                ("带URL规则", "@css:{div.content@text}\n<js>\nresult = result.replace(/\\n/g, '<br>');\n</js>"),
            ]
        case .javascript:
            return [
                ("JSON解析", "result = JSON.parse(result);"),
                ("数组遍历", "result.map(item => item.name).join('\\n');"),
                ("网络请求", "java.ajax(url).body;"),
                ("条件判断", "if (result.includes('关键词')) {\n  // 处理\n}"),
                ("正则匹配", "result.match(/pattern/g);"),
                ("字符串替换", "result.replace(/pattern/g, 'replacement');"),
            ]
        case .json:
            return [
                ("基础路径", "$.data"),
                ("数组遍历", "$.data[*]"),
                ("条件过滤", "$.data[?(@.type==1)]"),
                ("递归搜索", "$..name"),
            ]
        case .css:
            return [
                ("文本样式", "font-size: 16px;\nline-height: 1.8;\ncolor: #333;"),
                ("段落间距", "margin-bottom: 12px;\ntext-indent: 2em;"),
                ("图片居中", "display: block;\nmargin: 0 auto;\nmax-width: 100%;"),
            ]
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(snippets, id: \.0) { name, code in
                    Button(action: {
                        onInsert(code)
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(code)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("代码片段")
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
