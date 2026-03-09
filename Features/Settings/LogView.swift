//
//  LogView.swift
//  Legado-iOS
//
//  日志查看页面
//

import SwiftUI

struct LogView: View {
    @StateObject private var logManager = LogManager.shared
    @State private var selectedLevel: LogManager.LogLevel?
    @State private var searchText = ""
    @State private var showingClearConfirm = false
    @State private var showingShareSheet = false
    @State private var exportText = ""
    @State private var autoScroll = true
    
    var filteredLogs: [LogManager.LogEntry] {
        var logs = logManager.logs
        
        if let level = selectedLevel {
            logs = logs.filter { $0.level == level }
        }
        
        if !searchText.isEmpty {
            logs = logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        
        return logs
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索和筛选栏
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索日志...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 级别筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "全部",
                            isSelected: selectedLevel == nil,
                            color: .primary
                        ) {
                            selectedLevel = nil
                        }
                        
                        ForEach(LogManager.LogLevel.allCases, id: \.self) { level in
                            FilterChip(
                                title: level.rawValue,
                                isSelected: selectedLevel == level,
                                color: level.color
                            ) {
                                selectedLevel = level
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // 日志列表
            List {
                ForEach(filteredLogs) { entry in
                    LogEntryRow(entry: entry)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .overlay(
                Group {
                    if filteredLogs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("暂无日志")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            )
        }
        .navigationTitle("应用日志 (\(logManager.logs.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        exportText = logManager.export()
                        showingShareSheet = true
                    }) {
                        Label("导出日志", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        showingClearConfirm = true
                    }) {
                        Label("清空日志", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    
                    Toggle("自动滚动", isOn: $autoScroll)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("确认清空日志?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                logManager.clear()
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [exportText])
        }
    }
}

struct LogEntryRow: View {
    let entry: LogManager.LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.level.icon)
                    .font(.caption)
                
                Text(entry.formattedTime)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text("[\(entry.level.rawValue)]")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(entry.level.color)
                
                Spacer()
                
                Text("\(entry.shortFile):\(entry.line)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(isExpanded ? nil : 3)
                .onTapGesture {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(entry.level.color.opacity(0.1))
        )
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? color : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        LogView()
    }
}
