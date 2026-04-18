//
//  ReadAloudDialog.swift
//  Legado-iOS
//
//  对应 Android dialog_read_aloud.xml
//  顶部 上一章/快退/播放-暂停/停止/快进/下一章 + 定时 SeekBar + 语速 SeekBar + 底部目录/主菜单/后台/设置
//

import SwiftUI

struct ReadAloudDialog: View {
    @ObservedObject var ttsManager: TTSManager
    @ObservedObject var viewModel: ReaderViewModel
    @Binding var isPresented: Bool

    let onChapterList: () -> Void
    let onMainMenu: () -> Void
    let onToBackstage: () -> Void
    let onSettings: () -> Void

    @AppStorage("tts.rate") private var ttsRate: Double = 0.5
    @AppStorage("tts.followSystem") private var followSystem: Bool = false
    @AppStorage("tts.timerMinutes") private var timerMinutes: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            handle
            topRow
            timerRow
            speedRow
            Divider().padding(.horizontal, 16)
            bottomActionRow
        }
        .padding(.vertical, 6)
    }

    private var handle: some View {
        Capsule()
            .fill(Color(.systemGray3))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
    }

    // MARK: - 顶部：上一章 | 上一句 | 播放/暂停 | 停止 | 下一句 | 下一章

    private var topRow: some View {
        HStack(spacing: 0) {
            Button("上一章") { Task { await viewModel.prevChapter() } }
                .font(.system(size: 14))
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .foregroundColor(.primary)

            Spacer()

            transportButton(icon: "backward.end.fill", action: { /* prev sentence */ })
            transportButton(icon: isPlaying ? "pause.fill" : "play.fill", action: togglePlay)
            transportButton(icon: "stop.fill", action: { ttsManager.stop() })
            transportButton(icon: "forward.end.fill", action: { /* next sentence */ })

            Spacer()

            Button("下一章") { Task { await viewModel.nextChapter() } }
                .font(.system(size: 14))
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
    }

    private func transportButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.primary)
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 定时关闭 (对应 seek_timer + tv_timer)

    private var timerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.plus")
                .foregroundColor(.primary)
            Slider(value: $timerMinutes, in: 0...180, step: 5)
            Text(timerMinutes == 0 ? "关闭" : "\(Int(timerMinutes)) 分钟")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - 语速 (对应 seek_tts_speechRate + 跟随系统)

    private var speedRow: some View {
        VStack(spacing: 4) {
            HStack {
                Text("朗读语速")
                    .font(.system(size: 14))
                Text(String(format: "%.2f", ttsRate))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("跟随系统", isOn: $followSystem)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Text("跟随系统")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                Button { adjustRate(by: -0.05) } label: {
                    Image(systemName: "minus")
                        .frame(width: 30, height: 30)
                }
                Slider(value: $ttsRate, in: 0.1...1.0, step: 0.05)
                    .disabled(followSystem)
                Button { adjustRate(by: 0.05) } label: {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 30)
                }
            }
            .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - 底部 4 图文按钮

    private var bottomActionRow: some View {
        HStack {
            actionButton(icon: "list.bullet", title: "目录", action: onChapterList)
            Spacer()
            actionButton(icon: "line.3.horizontal", title: "主菜单", action: onMainMenu)
            Spacer()
            actionButton(icon: "eye.slash", title: "后台", action: onToBackstage)
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

    // MARK: - Helpers

    private var isPlaying: Bool {
        if case .speaking = ttsManager.state { return true }
        return false
    }

    private func togglePlay() {
        switch ttsManager.state {
        case .speaking: ttsManager.pause()
        case .paused: ttsManager.resume()
        case .idle:
            if let content = viewModel.chapterContent {
                ttsManager.speak(content)
            }
        default: break
        }
    }

    private func adjustRate(by delta: Double) {
        let next = max(0.1, min(1.0, ttsRate + delta))
        ttsRate = next
    }
}
