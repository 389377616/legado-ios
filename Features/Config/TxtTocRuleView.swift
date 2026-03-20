import SwiftUI
import CoreData

struct TxtTocRuleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "serialNumber", ascending: true)],
        animation: .default
    ) private var rules: FetchedResults<TxtTocRule>
    
    @State private var showingAdd = false
    @State private var editingRule: TxtTocRule?
    
    var body: some View {
        List {
            ForEach(rules) { rule in
                Button(action: { editingRule = rule }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rule.name)
                                .font(.headline)
                            Spacer()
                            if !rule.enabled {
                                Image(systemName: "pause.circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(rule.rule)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        if let example = rule.example, !example.isEmpty {
                            Text("示例: \(example)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .lineLimit(1)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .onDelete(perform: deleteRules)
        }
        .navigationTitle("TXT目录规则")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            TxtTocRuleEditView(rule: nil)
        }
        .sheet(item: $editingRule) { rule in
            TxtTocRuleEditView(rule: rule)
        }
    }
    
    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            viewContext.delete(rules[index])
        }
        try? viewContext.save()
    }
}

struct TxtTocRuleEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let rule: TxtTocRule?
    
    @State private var name = ""
    @State private var ruleText = ""
    @State private var example = ""
    @State private var enabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("规则名称", text: $name)
                    Toggle("启用", isOn: $enabled)
                }
                
                Section("正则规则") {
                    TextEditor(text: $ruleText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                }
                
                Section("示例文本") {
                    TextEditor(text: $example)
                        .font(.caption)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(rule == nil ? "添加规则" : "编辑规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .disabled(name.isEmpty || ruleText.isEmpty)
                }
            }
            .onAppear {
                if let rule = rule {
                    name = rule.name
                    ruleText = rule.rule
                    example = rule.example ?? ""
                    enabled = rule.enabled
                }
            }
        }
    }
    
    private func save() {
        let targetRule: TxtTocRule
        if let rule = rule {
            targetRule = rule
        } else {
            targetRule = TxtTocRule.create(in: viewContext)
            let count = try? viewContext.count(for: TxtTocRule.fetchRequest())
            targetRule.serialNumber = Int32(count ?? 0)
        }
        
        targetRule.name = name
        targetRule.rule = ruleText
        targetRule.example = example.isEmpty ? nil : example
        targetRule.enabled = enabled
        
        try? viewContext.save()
        dismiss()
    }
}

#Preview {
    NavigationView {
        TxtTocRuleView()
    }
}