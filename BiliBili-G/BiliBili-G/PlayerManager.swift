//
//  PlayerManager.swift
//  BiliBili
//
//  Shared AVPlayer manager — ensures only one video plays at a time.
//  When a new VideoPlayerView appears, it registers its player here and
//  the previously-playing player is paused automatically.
//

import AVFoundation

final class PlayerManager {
    static let shared = PlayerManager()

    /// The currently active (playing) AVPlayer. Weak so it can be deallocated
    /// when its owning view goes away.
    private weak var currentPlayer: AVPlayer?

    /// Persisted playback volume (0…1). Survives across video switches so the
    /// user's preferred volume is remembered from one video to the next.
    private(set) var volume: Float = 1.0
    private let volumeKey = "BiliBili.playerVolume"

    private init() {
        let stored = UserDefaults.standard.float(forKey: volumeKey)
        if stored > 0 || UserDefaults.standard.object(forKey: volumeKey) != nil {
            volume = max(0, min(1, stored))
        }
    }

    /// Register a player as the active one. Pauses any previously-active player
    /// and applies the persisted volume to the new player.
    func activate(_ player: AVPlayer) {
        if currentPlayer !== player {
            currentPlayer?.pause()
        }
        currentPlayer = player
        player.volume = volume
    }

    /// Stop tracking the given player (call on disappear / teardown).
    func deactivate(_ player: AVPlayer) {
        if currentPlayer === player {
            currentPlayer = nil
        }
    }

    /// Update the persisted volume and apply it to the active player.
    func setVolume(_ v: Float) {
        volume = max(0, min(1, v))
        UserDefaults.standard.set(volume, forKey: volumeKey)
        currentPlayer?.volume = volume
    }
}
