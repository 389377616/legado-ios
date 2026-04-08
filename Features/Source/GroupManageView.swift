import SwiftUI

struct GroupManageView: View {
    @ObservedObject var viewModel: SourceViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingAddGroup = false
    @State private var newGroupName = ""
    
    @MainActor
    init(viewModel: SourceViewModel = SourceViewModel()) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.allGroups.isEmpty {
                    Text("暂无分组")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.allGroups, id: \.self) { group in
                        HStack {
                            Text(group)
                            Spacer()
                            let count = viewModel.sources.filter { $0.bookSourceGroup == group }.count
                            Text("\(count) 个书源")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteGroups)
                }
            }
            .navigationTitle("分组管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newGroupName = ""
                        showingAddGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("新建分组", isPresented: $showingAddGroup) {
                TextField("分组名称", text: $newGroupName)
                Button("取消", role: .cancel) {}
                Button("确定") {
                    viewModel.createGroup(newGroupName)
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("请输入新的分组名称")
            }
        }
    }
    
    private func deleteGroups(at offsets: IndexSet) {
        for index in offsets {
            let group = viewModel.allGroups[index]
            viewModel.deleteGroup(group)
        }
    }
}
