import SwiftUI
import AVFoundation
import CoreData
import Combine

enum TTSEngineMode: String, CaseIterable {
    case local = "local"
    case online = "online"

    var displayName: String {
        switch self {
        case .local:
            return "本地"
        case .online:
            return "在线"
        }
    }
}

@MainActor
final class HttpTTSPlaybackController: ObservableObject {
    @Published private(set) var state: HttpTTSPlaybackState = .idle
    @Published private(set) var progress: HttpTTSPlaybackProgress = .init()
    @Published private(set) var engines: [HttpTTS] = []
    @Published var selectedEngineID: Int64?

    private var playbackManager: HttpTTSPlaybackManager?
    private var isInitialized = false

    init() {
    }

    private func ensureInitialized() async {
        guard !isInitialized else { return }
        isInitialized = true
        
        let manager = HttpTTSPlaybackManager()
        await manager.setCallbacks(
            onStateChange: { [weak self] newState in
                self?.state = newState
            },
            onProgressChange: { [weak self] newProgress in
                self?.progress = newProgress
            }
        )
        self.playbackManager = manager
    }

    func loadEngines() {
        let context = CoreDataStack.shared.viewContext
        let request = HttpTTS.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        request.predicate = NSPredicate(format: "enabled == YES")

        engines = (try? context.fetch(request)) ?? []

        if selectedEngineID == nil {
            selectedEngineID = engines.first?.id
        }

        if let selectedEngineID,
           engines.contains(where: { $0.id == selectedEngineID }) == false {
            self.selectedEngineID = engines.first?.id
        }
    }

    func restoreSelection(from storedEngineID: Int) {
        let engineID = Int64(storedEngineID)
        if engineID > 0,
           engines.contains(where: { $0.id == engineID }) {
            selectedEngineID = engineID
        } else if selectedEngineID == nil {
            selectedEngineID = engines.first?.id
        }
    }

    var selectedEngine: HttpTTS? {
        guard let selectedEngineID else { return nil }
        return engines.first { $0.id == selectedEngineID }
    }

    var selectedEngineName: String {
        selectedEngine?.name ?? "未选择"
    }

    var selectedEngineURL: String {
        selectedEngine?.url ?? ""
    }

    func speak(text: String) {
        guard let engine = selectedEngine else {
            state = .failed("请先在设置中启用并选择在线TTS引擎")
            return
        }

        Task {
            await ensureInitialized()
            await playbackManager?.speak(text: text, config: engine)
        }
    }

    func pause() {
        Task {
            await playbackManager?.pause()
        }
    }

    func resume() {
        Task {
            await playbackManager?.resume()
        }
    }

    func stop() {
        Task {
            await playbackManager?.stop()
        }
    }
}

struct TTSControlsView: View {
    @ObservedObject var ttsManager: TTSManager
    @ObservedObject var viewModel: ReaderViewModel
    @Binding var isPresented: Bool

    @StateObject private var onlineController = HttpTTSPlaybackController()
    @State private var showVoicePicker = false
    @State private var showSleepTimerOptions = false
    @State private var showCustomSleepTimerSheet = false
    @State private var customSleepMinutes = 90
    @State private var sleepTimerEndDate: Date?
    @State private var sleepTimerRemainingSeconds = 0

    @AppStorage("tts.engine.mode") private var engineModeRaw: String = TTSEngineMode.local.rawValue
    @AppStorage("tts.online.engineId") private var storedOnlineEngineID: Int = 0
    @Environment(\.scenePhase) private var scenePhase

    private let sleepTimerTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var engineMode: TTSEngineMode {
        get { TTSEngineMode(rawValue: engineModeRaw) ?? .local }
        set { engineModeRaw = newValue.rawValue }
    }

    private var engineModeBinding: Binding<TTSEngineMode> {
        Binding(
            get: { TTSEngineMode(rawValue: engineModeRaw) ?? .local },
            set: { engineModeRaw = $0.rawValue }
        )
    }

    private var isOnlineEngine: Bool {
        engineMode == .online
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("语音朗读")
                    .font(.headline)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            statusView

            if shouldShowProgress {
                progressView
            }

            controlButtons

            Divider()

            settingsSection

            Divider()

            sleepTimerSection
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
        .task {
            onlineController.loadEngines()
            onlineController.restoreSelection(from: storedOnlineEngineID)
            refreshSleepTimerCountdown(referenceDate: Date())
        }
        .onDisappear {
            onlineController.stop()
        }
        .onReceive(sleepTimerTicker) { _ in
            refreshSleepTimerCountdown(referenceDate: Date())
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                refreshSleepTimerCountdown(referenceDate: Date())
            }
        }
        .onChange(of: onlineController.selectedEngineID) { newValue in
            storedOnlineEngineID = newValue.map { Int($0) } ?? 0
        }
        .onChange(of: engineModeRaw) { newValue in
            if newValue == TTSEngineMode.online.rawValue {
                ttsManager.stop()
                onlineController.loadEngines()
                onlineController.restoreSelection(from: storedOnlineEngineID)
            } else {
                onlineController.stop()
            }
        }
    }

    private var statusView: some View {
        HStack {
            if isOnlineEngine {
                switch onlineController.state {
                case .idle:
                    Image(systemName: "speaker.slash")
                        .foregroundColor(.secondary)
                    Text("未开始")
                        .foregroundColor(.secondary)

                case .loading:
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                    Text("正在下载音频...")
                        .foregroundColor(.primary)

                case .playing:
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.blue)
                    Text("正在播放在线语音...")
                        .foregroundColor(.primary)

                case .paused:
                    Image(systemName: "speaker.wave.1")
                        .foregroundColor(.orange)
                    Text("已暂停")
                        .foregroundColor(.orange)

                case .stopped:
                    Image(systemName: "stop.circle")
                        .foregroundColor(.secondary)
                    Text("已停止")
                        .foregroundColor(.secondary)

                case .failed(let message):
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(message)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            } else {
                switch ttsManager.state {
                case .idle:
                    Image(systemName: "speaker.slash")
                        .foregroundColor(.secondary)
                    Text("未开始")
                        .foregroundColor(.secondary)

                case .speaking:
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.blue)
                    Text("正在朗读...")
                        .foregroundColor(.primary)

                case .paused:
                    Image(systemName: "speaker.wave.1")
                        .foregroundColor(.orange)
                    Text("已暂停")
                        .foregroundColor(.orange)

                case .error(let message):
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(message)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
    }

    private var shouldShowProgress: Bool {
        if isOnlineEngine {
            onlineController.state.isActive || onlineController.state == .stopped
        } else {
            ttsManager.state.isSpeaking || ttsManager.state.isPaused
        }
    }

    private var progressView: some View {
        VStack(spacing: 8) {
            if isOnlineEngine {
                if onlineController.state == .loading {
                    ProgressView()
                        .progressViewStyle(.linear)
                } else {
                    ProgressView(value: onlineController.progress.progress)
                        .progressViewStyle(.linear)
                }

                HStack {
                    Text("\(formatDuration(onlineController.progress.currentTime)) / \(formatDuration(onlineController.progress.duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(onlineController.progress.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView(value: Double(ttsManager.spokenCharacters), total: Double(ttsManager.totalCharacters))
                    .progressViewStyle(.linear)

                HStack {
                    Text("已朗读 \(ttsManager.spokenCharacters) / \(ttsManager.totalCharacters) 字")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(Double(ttsManager.spokenCharacters) / Double(max(1, ttsManager.totalCharacters)) * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 24) {
            Button {
                if !isOnlineEngine {
                    ttsManager.previousParagraph()
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .disabled(!canNavigateBack)

            Button {
                togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 56, height: 56)

                    Image(systemName: playPauseIcon)
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            .disabled(isOnlineEngine && onlineController.state == .loading)

            Button {
                if !isOnlineEngine {
                    ttsManager.nextParagraph()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .disabled(!canNavigateForward)

            Button {
                stopPlayback()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
        }
        .foregroundColor(.primary)
    }

    private var playPauseIcon: String {
        if isOnlineEngine {
            return onlineController.state.isPlaying ? "pause.fill" : "play.fill"
        }
        return ttsManager.state.isSpeaking ? "pause.fill" : "play.fill"
    }

    private var canNavigateBack: Bool {
        !isOnlineEngine && (ttsManager.state.isSpeaking || ttsManager.state.isPaused)
    }

    private var canNavigateForward: Bool {
        !isOnlineEngine && (ttsManager.state.isSpeaking || ttsManager.state.isPaused)
    }

    private var settingsSection: some View {
        VStack(spacing: 16) {
            Picker("朗读引擎", selection: engineModeBinding) {
                ForEach(TTSEngineMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if isOnlineEngine {
                onlineEnginePicker
            } else {
                localSettings
            }
        }
    }

    private var sleepTimerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("定时关闭", systemImage: "timer")
                    .font(.subheadline)

                Spacer()

                if hasActiveSleepTimer {
                    Text("剩余 \(formatRemainingTime(sleepTimerRemainingSeconds))")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("未开启")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button(hasActiveSleepTimer ? "重新设置" : "定时关闭") {
                    showSleepTimerOptions = true
                }
                .buttonStyle(.bordered)

                if hasActiveSleepTimer {
                    Button("取消定时", role: .destructive) {
                        cancelSleepTimer()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("提示：iOS 在后台时定时器刷新可能暂停，回到前台会根据目标时间重新计算并在到时后停止朗读。")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .confirmationDialog("定时关闭", isPresented: $showSleepTimerOptions, titleVisibility: .visible) {
            Button("15 分钟") {
                startSleepTimer(minutes: 15)
            }
            Button("30 分钟") {
                startSleepTimer(minutes: 30)
            }
            Button("60 分钟") {
                startSleepTimer(minutes: 60)
            }
            Button("自定义时长") {
                showCustomSleepTimerSheet = true
            }

            if hasActiveSleepTimer {
                Button("取消定时", role: .destructive) {
                    cancelSleepTimer()
                }
            }

            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showCustomSleepTimerSheet) {
            customSleepTimerSheet
        }
    }

    private var customSleepTimerSheet: some View {
        NavigationView {
            Form {
                Section("时长") {
                    Stepper(value: $customSleepMinutes, in: 5...360, step: 5) {
                        Text("\(customSleepMinutes) 分钟")
                    }
                }

                Section {
                    Text("到时会自动停止当前朗读，你也可以随时手动取消定时。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("自定义定时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showCustomSleepTimerSheet = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        startSleepTimer(minutes: customSleepMinutes)
                        showCustomSleepTimerSheet = false
                    }
                }
            }
        }
    }

    private var onlineEnginePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            if onlineController.engines.isEmpty {
                Text("暂无可用在线TTS引擎，请先到设置页添加")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Picker("在线引擎", selection: Binding(
                    get: { onlineController.selectedEngineID ?? onlineController.engines.first?.id ?? 0 },
                    set: { onlineController.selectedEngineID = $0 }
                )) {
                    ForEach(onlineController.engines, id: \.id) { engine in
                        Text(engine.name).tag(engine.id)
                    }
                }
                .pickerStyle(.menu)

                if !onlineController.selectedEngineURL.isEmpty {
                    Text(onlineController.selectedEngineURL)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var localSettings: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("语速")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f", ttsManager.config.rate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "tortoise")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: Binding(
                        get: { ttsManager.config.rate },
                        set: { ttsManager.setRate($0) }
                    ), in: 0.0...1.0)

                    Image(systemName: "hare")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("音调")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f", ttsManager.config.pitch))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { ttsManager.config.pitch },
                    set: { ttsManager.setPitch($0) }
                ), in: 0.5...2.0)
            }

            Button {
                showVoicePicker = true
            } label: {
                HStack {
                    Text("声音")
                        .font(.subheadline)

                    Spacer()

                    Text(currentVoiceName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showVoicePicker) {
                VoicePickerView(ttsManager: ttsManager, isPresented: $showVoicePicker)
            }
        }
    }

    private var currentVoiceName: String {
        if let voiceId = ttsManager.config.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            return voice.name
        }
        return "系统默认"
    }

    private func togglePlayback() {
        if isOnlineEngine {
            if onlineController.state.isPlaying {
                onlineController.pause()
            } else if onlineController.state.isPaused {
                onlineController.resume()
            } else {
                startReading()
            }
            return
        }

        if ttsManager.state.isSpeaking {
            ttsManager.pause()
        } else if ttsManager.state.isPaused {
            ttsManager.resume()
        } else {
            startReading()
        }
    }

    private func stopPlayback() {
        if isOnlineEngine {
            onlineController.stop()
        } else {
            ttsManager.stop()
        }
    }

    private func startReading() {
        guard let content = viewModel.chapterContent?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            return
        }

        if isOnlineEngine {
            ttsManager.stop()
            onlineController.speak(text: content)
            return
        }

        onlineController.stop()

        let pages = content.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        ttsManager.speakParagraphs(
            pages,
            onParagraphComplete: {},
            onTextComplete: {}
        )
    }

    private var hasActiveSleepTimer: Bool {
        sleepTimerEndDate != nil && sleepTimerRemainingSeconds > 0
    }

    private func startSleepTimer(minutes: Int) {
        let safeMinutes = max(1, minutes)
        sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(safeMinutes * 60))
        refreshSleepTimerCountdown(referenceDate: Date())
    }

    private func cancelSleepTimer() {
        sleepTimerEndDate = nil
        sleepTimerRemainingSeconds = 0
    }

    private func refreshSleepTimerCountdown(referenceDate: Date) {
        guard let endDate = sleepTimerEndDate else { return }

        let remaining = Int(endDate.timeIntervalSince(referenceDate))
        if remaining <= 0 {
            cancelSleepTimer()
            stopPlayback()
            return
        }

        sleepTimerRemainingSeconds = remaining
    }

    private func formatRemainingTime(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let second = clamped % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, second)
        }

        return String(format: "%02d:%02d", minutes, second)
    }

    private func formatDuration(_ value: TimeInterval) -> String {
        let totalSeconds = max(0, Int(value))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct VoicePickerView: View {
    @ObservedObject var ttsManager: TTSManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                Button {
                    ttsManager.setVoice(nil)
                    isPresented = false
                } label: {
                    HStack {
                        Text("系统默认")
                        Spacer()
                        if ttsManager.config.voiceIdentifier == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }

                ForEach(groupedVoices.keys.sorted(), id: \.self) { language in
                    Section(header: Text(languageDisplayName(language))) {
                        ForEach(groupedVoices[language] ?? [], id: \.identifier) { voice in
                            Button {
                                ttsManager.setVoice(voice)
                                isPresented = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(voice.name)
                                        Text(voice.identifier)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if ttsManager.config.voiceIdentifier == voice.identifier {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择声音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private var groupedVoices: [String: [AVSpeechSynthesisVoice]] {
        Dictionary(grouping: ttsManager.availableVoices) { voice in
            voice.language
        }
    }

    private func languageDisplayName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()

        TTSControlsView(
            ttsManager: TTSManager(),
            viewModel: ReaderViewModel(),
            isPresented: .constant(true)
        )
    }
}
