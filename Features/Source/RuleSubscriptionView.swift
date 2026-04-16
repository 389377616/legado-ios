import SwiftUI
import CoreData

struct RuleSubscriptionView: View {
    @StateObject private var viewModel = RuleSubscriptionManager()
    @State private var selectedType: RuleSub.SubType = .bookSource
    @State private var showingAddSheet = false
    @State private var showingImportSheet = false

    var body: some View {
        VStack(spacing: 0) {
            typePicker

            if viewModel.subscriptions.isEmpty {
                emptyView
            } else {
                subscriptionList
            }
        }
        .navigationTitle("规则订阅")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAddSheet = true }) {
                        Label("添加订阅", systemImage: "plus")
                    }
                    Button(action: { showingImportSheet = true }) {
                        Label("从URL导入", systemImage: "link")
                    }
                    Divider()
                    Button(action: { Task { await viewModel.updateAllSubscriptions() } }) {
                        Label("更新全部", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addSubscriptionSheet
        }
        .sheet(isPresented: $showingImportSheet) {
            importFromUrlSheet
        }
        .task {
            viewModel.loadSubscriptions(type: selectedType)
        }
        .overlay {
            if viewModel.isUpdating {
                updateProgressOverlay
            }
        }
    }

    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RuleSub.SubType.allCases, id: \.rawValue) { type in
                    Button(action: {
                        selectedType = type
                        viewModel.loadSubscriptions(type: type)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: typeIcon(type))
                                .font(.caption)
                            Text(type.title)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedType == type
                                ? Color.accentColor.opacity(0.15)
                                : Color(.systemGray6)
                        )
                        .foregroundColor(selectedType == type ? .accentColor : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private func typeIcon(_ type: RuleSub.SubType) -> String {
        type.iconName
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("暂无\(selectedType.title)订阅")
                .font(.headline)
            Text("点击右上角 + 添加订阅规则")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subscriptionList: some View {
        List {
            ForEach(viewModel.subscriptions, id: \.id) { sub in
                SubscriptionRow(subscription: sub) {
                    viewModel.deleteSubscription(sub)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteSubscription(sub)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        Task { try? await viewModel.updateSubscription(id: sub.id) }
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                    .tint(.blue)
                }
            }
            .onMove { from, to in
                viewModel.moveSubscription(from: from, to: to)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var updateProgressOverlay: some View {
        VStack(spacing: 12) {
            ProgressView(value: viewModel.updateProgress) {
                Text("正在更新订阅...")
                    .font(.subheadline)
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 40)

            Text("\(Int(viewModel.updateProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }

    private var addSubscriptionSheet: some View {
        NavigationView {
            AddRuleSubscriptionView(selectedType: selectedType, viewModel: viewModel)
        }
    }

    private var importFromUrlSheet: some View {
        NavigationView {
            ImportRuleFromUrlView(selectedType: selectedType, viewModel: viewModel)
        }
    }
}

struct SubscriptionRow: View {
    let subscription: RuleSub
    let onDelete: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name.isEmpty ? "未命名订阅" : subscription.name)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(subscription.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if subscription.autoUpdate {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                if subscription.lastUpdateTime > 0 {
                    Text(Date(timeIntervalSince1970: TimeInterval(subscription.lastUpdateTime / 1000)).formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("类型:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(subscription.subType?.title ?? "未知")
                            .font(.caption)
                    }
                    HStack {
                        Text("自动更新:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(subscription.autoUpdate ? "开启" : "关闭")
                            .font(.caption)
                    }
                    HStack {
                        Text("排序:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(subscription.customOrder)")
                            .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { isExpanded.toggle() } }
    }
}

struct AddRuleSubscriptionView: View {
    let selectedType: RuleSub.SubType
    @ObservedObject var viewModel: RuleSubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var autoUpdate = true
    @State private var type: RuleSub.SubType

    init(selectedType: RuleSub.SubType, viewModel: RuleSubscriptionManager) {
        self.selectedType = selectedType
        self.viewModel = viewModel
        _type = State(initialValue: selectedType)
    }

    var body: some View {
        Form {
            Section("订阅信息") {
                TextField("订阅名称", text: $name)

                TextField("订阅URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Picker("规则类型", selection: $type) {
                    ForEach(RuleSub.SubType.allCases, id: \.rawValue) { t in
                        Text(t.title).tag(t)
                    }
                }
            }

            Section("更新设置") {
                Toggle("自动更新", isOn: $autoUpdate)
            }
        }
        .navigationTitle("添加订阅")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("添加") {
                    viewModel.addSubscription(name: name, url: url, type: type, autoUpdate: autoUpdate)
                    dismiss()
                }
                .disabled(name.isEmpty || url.isEmpty)
            }
        }
    }
}

struct ImportRuleFromUrlView: View {
    let selectedType: RuleSub.SubType
    @ObservedObject var viewModel: RuleSubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var isImporting = false
    @State private var importResult: String?

    var body: some View {
        Form {
            Section("导入规则") {
                TextField("输入规则URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Picker("规则类型", selection: .constant(selectedType)) {
                    Text(selectedType.title).tag(selectedType)
                }
                .disabled(true)
            }

            if let result = importResult {
                Section("结果") {
                    Text(result)
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }

            Section {
                Button(action: importRules) {
                    HStack {
                        Spacer()
                        if isImporting {
                            ProgressView()
                        } else {
                            Text("开始导入")
                                .fontWeight(.medium)
                        }
                        Spacer()
                    }
                }
                .disabled(url.isEmpty || isImporting)
            }
        }
        .navigationTitle("从URL导入")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
    }

    private func importRules() {
        guard !url.isEmpty else { return }
        isImporting = true
        importResult = nil

        Task {
            do {
                try await viewModel.updateSubscription(id: 0)
                importResult = "导入成功"
            } catch {
                importResult = "导入失败: \(error.localizedDescription)"
            }
            isImporting = false
        }
    }
}
