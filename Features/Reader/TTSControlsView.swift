import SwiftUI
import AVFoundation
import CoreData

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

    func restoreSelection(from storedEngineID: Int64) {
        if storedEngineID > 0,
           engines.contains(where: { $0.id == storedEngineID }) {
            selectedEngineID = storedEngineID
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

    @AppStorage("tts.engine.mode") private var engineModeRaw: String = TTSEngineMode.local.rawValue
    @AppStorage("tts.online.engineId") private var storedOnlineEngineID: Int64 = 0

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
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
        .task {
            onlineController.loadEngines()
            onlineController.restoreSelection(from: storedOnlineEngineID)
        }
        .onDisappear {
            onlineController.stop()
        }
        .onChange(of: onlineController.selectedEngineID) { newValue in
            storedOnlineEngineID = newValue ?? 0
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
