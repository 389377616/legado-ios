import Foundation
import MediaPlayer

@MainActor
class RemoteCommandHandler {
    private var audioManager: AudioPlayManager?
    
    init() {}
    
    func configure(with audioManager: AudioPlayManager) {
        self.audioManager = audioManager
        setupCommands()
    }
    
    private func setupCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.audioManager?.play() }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.audioManager?.pause() }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in await self?.audioManager?.nextChapter() }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in await self?.audioManager?.prevChapter() }
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [15, 30, 60]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.audioManager?.seek(by: skipEvent.interval) }
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [15, 30, 60]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.audioManager?.seek(by: -skipEvent.interval) }
            return .success
        }
    }
    
    func updateNowPlaying(title: String, artist: String, album: String, duration: Double, elapsedTime: Double, rate: Float) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: rate
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
