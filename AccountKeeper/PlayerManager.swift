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

    private init() {}

    /// Register a player as the active one. Pauses any previously-active player.
    func activate(_ player: AVPlayer) {
        if currentPlayer !== player {
            currentPlayer?.pause()
        }
        currentPlayer = player
    }

    /// Stop tracking the given player (call on disappear / teardown).
    func deactivate(_ player: AVPlayer) {
        if currentPlayer === player {
            currentPlayer = nil
        }
    }
}
