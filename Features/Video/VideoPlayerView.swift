import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL?
    let book: Book?
    
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("无法加载视频")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("视频播放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        player?.pause()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func setupPlayer() {
        guard let url = videoURL else { return }
        player = AVPlayer(url: url)
    }
}

struct VideoPlayerControlsView: View {
    @ObservedObject var player: AVPlayer
    @Binding var isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 30) {
            Button(action: { seekBackward() }) {
                Image(systemName: "gobackward.15")
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            Button(action: { togglePlay() }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            
            Button(action: { seekForward() }) {
                Image(systemName: "goforward.15")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
    
    private func togglePlay() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func seekBackward() {
        let time = player.currentTime() - CMTime(seconds: 15, preferredTimescale: 1)
        player.seek(to: time)
    }
    
    private func seekForward() {
        let time = player.currentTime() + CMTime(seconds: 15, preferredTimescale: 1)
        player.seek(to: time)
    }
}