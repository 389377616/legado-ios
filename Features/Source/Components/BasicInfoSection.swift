import SwiftUI

struct BasicInfoSection: View {
    @ObservedObject var viewModel: SourceEditViewModel

    var body: some View {
        Section {
            HStack {
                Text("类型")
                Spacer()
                Picker("", selection: $viewModel.source.bookSourceType) {
                    Text("文本").tag(Int32(0))
                    Text("音频").tag(Int32(1))
                    Text("图片").tag(Int32(2))
                }
                .pickerStyle(.menu)
            }
            
            Toggle("启用", isOn: $viewModel.source.enabled)
            Toggle("发现", isOn: $viewModel.source.enabledExplore)
        }
        
        Section("基本信息") {
            RuleFieldEditor(
                title: "书源地址",
                text: $viewModel.source.bookSourceUrl,
                placeholder: "https://example.com"
            )

            RuleFieldEditor(
                title: "书源名称",
                text: $viewModel.source.bookSourceName,
                placeholder: "书源名称"
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("书源分组")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !viewModel.allGroups.isEmpty {
                        Menu {
                            ForEach(viewModel.allGroups, id: \.self) { group in
                                Button(group) {
                                    viewModel.source.bookSourceGroup = group
                                }
                            }
                        } label: {
                            Text("选择现有")
                                .font(.caption)
                        }
                    }
                }
                
                TextField("可选分组", text: $viewModel.source.bookSourceGroup.orEmpty)
            }

            RuleFieldEditor(
                title: "请求头 Header (JSON)",
                text: $viewModel.source.header.orEmpty,
                placeholder: "{\"User-Agent\":\"...\"}",
                isMultiline: true
            )

            RuleFieldEditor(
                title: "登录地址",
                text: $viewModel.source.loginUrl.orEmpty,
                placeholder: "https://example.com/login"
            )
        }
    }
}
