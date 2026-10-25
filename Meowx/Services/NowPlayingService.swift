import AppKit
import MediaPlayer

final class NowPlayingService {
    static let shared = NowPlayingService()
    private var installed = false

    func install() {
        guard !installed else { return }
        installed = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in
            PlayerModel.shared.play()
            return .success
        }
        center.pauseCommand.addTarget { _ in
            PlayerModel.shared.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            PlayerModel.shared.togglePause()
            return .success
        }
        center.nextTrackCommand.addTarget { _ in
            PlayerModel.shared.next()
            return .success
        }
        center.previousTrackCommand.addTarget { _ in
            PlayerModel.shared.previous()
            return .success
        }
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            PlayerModel.shared.seek(to: event.positionTime, exact: true)
            return .success
        }
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { _ in
            PlayerModel.shared.seek(by: 15)
            return .success
        }
        center.skipBackwardCommand.addTarget { _ in
            PlayerModel.shared.seek(by: -15)
            return .success
        }
    }

    func update(model: PlayerModel) {
        guard model.playlist.current != nil else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: model.displayTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: model.position,
            MPNowPlayingInfoPropertyPlaybackRate: model.paused ? 0 : model.speed,
            MPNowPlayingInfoPropertyMediaType: model.showsVideo
                ? MPNowPlayingInfoMediaType.video.rawValue
                : MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if model.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = model.duration
        }
        if !model.artist.isEmpty {
            info[MPMediaItemPropertyArtist] = model.artist
        }
        if let artwork = model.artwork {
            let size = artwork.size == .zero ? NSSize(width: 300, height: 300) : artwork.size
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: size) { _ in artwork }
        }
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = info
        center.playbackState = model.paused ? .paused : .playing
    }
}
