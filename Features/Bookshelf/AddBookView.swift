//
//  AddBookView.swift
//  Legado-iOS
//
//  添加书籍界面
//

import SwiftUI

struct AddBookView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchResults: [String] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Text("添加书籍功能开发中")
                    .foregroundColor(.secondary)
                
                Text("可以通过以下方式添加：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                List {
                    Button("本地导入") {
                        // TODO: 导入本地书籍
                    }
                    
                    Button("扫码添加") {
                        // TODO: 扫码
                    }
                    
                    Button("搜索添加") {
                        // TODO: 搜索
                    }
                }
            }
            .navigationTitle("添加书籍")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddBookView()
}
