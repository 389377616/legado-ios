import SwiftUI

struct TTSSettingsView: View {
    @AppStorage("tts.rate") private var ttsRate = 0.5
    @AppStorage("tts.pitch") private var ttsPitch = 1.0
    @AppStorage("tts.volume") private var ttsVolume = 1.0
    
    var body: some View {
        List {
            Section("朗读速度") {
                Slider(value: $ttsRate, in: 0.0...1.0) {
                    Text("速度: \(Int(ttsRate * 100))%")
                }
            }
            
            Section("音调") {
                Slider(value: $ttsPitch, in: 0.5...2.0) {
                    Text("音调: \(String(format: "%.1f", ttsPitch))")
                }
            }
            
            Section("音量") {
                Slider(value: $ttsVolume, in: 0.0...1.0) {
                    Text("音量: \(Int(ttsVolume * 100))%")
                }
            }
        }
        .navigationTitle("朗读设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}