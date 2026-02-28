//
//  ReplaceRuleView.swift
//  Legado-iOS
//
//  替换规则管理界面
//

import SwiftUI
import CoreData

struct ReplaceRuleView: View {
    @StateObject private var viewModel = ReplaceRuleViewModel()
    @State private var showingEdit = false
    @State private var selectedRule: ReplaceRule?
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.rules.isEmpty {
                    EmptyStateView(
                        title: "暂无替换规则",
                        subtitle: "点击右上角添加替换规则",
                        imageName: "text.badge.checkmark"
                    )
                } else {
                    ForEach(viewModel.rules, id: \.ruleId) { rule in
                        ReplaceRuleItemView(rule: rule)
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteRule(rule)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    selectedRule = rule
                                    showingEdit = true
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                                
                                Button {
                                    viewModel.toggleRule(rule)
                                } label: {
                                    Label(rule.enabled ? "禁用" : "启用", systemImage: rule.enabled ? "xmark.circle" : "checkmark.circle")
                                }
                            }
                    }
                    .onMove { source, destination in
                        viewModel.moveRule(from: source, to: destination)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("替换规则")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedRule = nil
                        showingEdit = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                if let rule = selectedRule {
                    ReplaceRuleEditView(rule: rule, viewModel: viewModel)
                } else {
                    ReplaceRuleEditView(rule: nil, viewModel: viewModel)
                }
            }
            .task {
                await viewModel.loadRules()
            }
        }
    }
}

// MARK: - 规则列表项
struct ReplaceRuleItemView: View {
    let rule: ReplaceRule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rule.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                Circle()
                    .fill(rule.enabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            
            Text(rule.pattern)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .monospaced()
            
            HStack {
                Text(rule.scope == "global" ? "全局" : "书源")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("优先级：\(rule.priority)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 编辑界面
struct ReplaceRuleEditView: View {
    let rule: ReplaceRule?
    @ObservedObject var viewModel: ReplaceRuleViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var pattern = ""
    @State private var replacement = ""
    @State private var scope: String = "global"
    @State private var scopeId: String = ""
    @State private var isRegex = true
    @State private var enabled = true
    @State private var priority: Int32 = 0
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("规则信息")) {
                    TextField("规则名称", text: $name)
                    
                    TextField("匹配模式", text: $pattern)
                        .font(.system(.caption, design: .monospaced))
                    
                    TextField("替换为", text: $replacement)
                        .font(.system(.caption, design: .monospaced))
                }
                
                Section(header: Text("作用范围")) {
                    Picker("范围", selection: $scope) {
                        Text("全局").tag("global")
                        Text("书源").tag("source")
                        Text("书籍").tag("book")
                    }
                    
                    if scope != "global" {
                        TextField("范围 ID", text: $scopeId)
                    }
                }
                
                Section(header: Text("高级选项")) {
                    Toggle("正则表达式", isOn: $isRegex)
                    
                    Stepper("优先级：\(priority)", value: $priority, in: -10...10)
                    
                    Toggle("启用", isOn: $enabled)
                }
                
                Section {
                    Text("正则表达式示例：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• \\\\s+ - 匹配空白字符")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("• <.*?> - 匹配 HTML 标签")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(rule == nil ? "新建规则" : "编辑规则")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        save()
                    }
                    .disabled(name.isEmpty || pattern.isEmpty)
                }
            }
            .onAppear {
                if let rule = rule {
                    name = rule.name
                    pattern = rule.pattern
                    replacement = rule.replacement
                    scope = rule.scope
                    scopeId = rule.scopeId ?? ""
                    isRegex = rule.isRegex
                    enabled = rule.enabled
                    priority = rule.priority
                }
            }
        }
    }
    
    private func save() {
        if let rule = rule {
            viewModel.updateRule(
                rule,
                name: name,
                pattern: pattern,
                replacement: replacement,
                scope: scope,
                scopeId: scopeId.isEmpty ? nil : scopeId,
                isRegex: isRegex,
                enabled: enabled,
                priority: priority
            )
        } else {
            viewModel.createRule(
                name: name,
                pattern: pattern,
                replacement: replacement,
                scope: scope,
                scopeId: scopeId.isEmpty ? nil : scopeId,
                isRegex: isRegex,
                enabled: enabled,
                priority: priority
            )
        }
        dismiss()
    }
}

// MARK: - ViewModel
class ReplaceRuleViewModel: ObservableObject {
    @Published var rules: [ReplaceRule] = []
    
    func loadRules() async {
        do {
            let request: NSFetchRequest<ReplaceRule> = ReplaceRule.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "scope", ascending: true),
                NSSortDescriptor(key: "priority", ascending: false),
                NSSortDescriptor(key: "order", ascending: true)
            ]
            
            rules = try CoreDataStack.shared.viewContext.fetch(request)
        } catch {
            print("加载规则失败：\(error)")
        }
    }
    
    func createRule(
        name: String,
        pattern: String,
        replacement: String,
        scope: String,
        scopeId: String?,
        isRegex: Bool,
        enabled: Bool,
        priority: Int32
    ) {
        let context = CoreDataStack.shared.viewContext
        let rule = ReplaceRule.create(in: context)
        
        rule.name = name
        rule.pattern = pattern
        rule.replacement = replacement
        rule.scope = scope
        rule.scopeId = scopeId
        rule.isRegex = isRegex
        rule.enabled = enabled
        rule.priority = priority
        
        try? CoreDataStack.shared.save()
        Task {
            await loadRules()
        }
    }
    
    func updateRule(
        _ rule: ReplaceRule,
        name: String,
        pattern: String,
        replacement: String,
        scope: String,
        scopeId: String?,
        isRegex: Bool,
        enabled: Bool,
        priority: Int32
    ) {
        rule.name = name
        rule.pattern = pattern
        rule.replacement = replacement
        rule.scope = scope
        rule.scopeId = scopeId
        rule.isRegex = isRegex
        rule.enabled = enabled
        rule.priority = priority
        
        try? CoreDataStack.shared.save()
        Task {
            await loadRules()
        }
    }
    
    func deleteRule(_ rule: ReplaceRule) {
        CoreDataStack.shared.viewContext.delete(rule)
        try? CoreDataStack.shared.save()
        Task {
            await loadRules()
        }
    }
    
    func toggleRule(_ rule: ReplaceRule) {
        rule.enabled.toggle()
        try? CoreDataStack.shared.save()
    }
    
    func moveRule(from source: IndexSet, to destination: Int) {
        // TODO: 实现排序
    }
}

#Preview {
    ReplaceRuleView()
}
