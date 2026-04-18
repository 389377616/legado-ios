//
//  AutoReadDialog.swift
//  Legado-iOS
//
//  对应 Android dialog_auto_read.xml
//  自动翻页速度条 + 底部 目录/主菜单/停止/设置
//

import SwiftUI

struct AutoReadDialog: View {
    @ObservedObject var manager: AutoPageTurnManager
    @Binding var isPresented: Bool

    let onChapterList: () -> Void
    let onMainMenu: () -> Void
    let onSettings: () -> Void

    @State private var speedValue: Double = 5

    var body: some View {
        VStack(spacing: 10) {
            handle
            speedSection
            Divider().padding(.horizontal, 16)
            bottomActionRow
        }
        .padding(.vertical, 6)
        .onAppear { speedValue = Double(manager.config.interval) }
    }

    private var handle: some View {
        Capsule()
            .fill(Color(.systemGray3))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
    }

    private var speedSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("翻页速度")
                    .font(.system(size: 14))
                Spacer()
                Text("\(Int(speedValue)) 秒")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Slider(value: $speedValue, in: 1...120, step: 1)
                .onChange(of: speedValue) { newValue in
                    manager.setInterval(newValue)
                }
        }
        .padding(.horizontal, 16)
    }

    private var bottomActionRow: some View {
        HStack {
            actionButton(icon: "list.bullet", title: "目录", action: onChapterList)
            Spacer()
            actionButton(icon: "line.3.horizontal", title: "主菜单", action: onMainMenu)
            Spacer()
            actionButton(icon: "stop.circle", title: "停止", action: {
                manager.stop()
                isPresented = false
            })
            Spacer()
            actionButton(icon: "gearshape", title: "设置", action: onSettings)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
    }

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(.primary)
            .frame(width: 60)
        }
    }
}
