//
//  AddBookView.swift
//  Legado-iOS
//
//  添加书籍界面
//

import SwiftUI

struct AddBookView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var pendingFilePicker: Bool

    @State private var showingQRScanner = false
    @State private var showingSearch = false
    
    var body: some View {
        NavigationView {
            List {
                Button {
                    pendingFilePicker = true
                    dismiss()
                } label: {
                    Label("本地导入", systemImage: "folder")
                }

                Button {
                    showingQRScanner = true
                } label: {
                    Label("扫码添加", systemImage: "qrcode.viewfinder")
                }

                Button {
                    showingSearch = true
                } label: {
                    Label("搜索添加", systemImage: "magnifyingglass")
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
            .sheet(isPresented: $showingQRScanner) {
                QRCodeScanView()
            }
            .sheet(isPresented: $showingSearch) {
                NavigationStack { SearchResultView() }
            }
        }
    }
}

#Preview {
    AddBookView(pendingFilePicker: .constant(false))
}
