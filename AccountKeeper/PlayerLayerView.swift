//
//  PlayerLayerView.swift
//  BiliBili
//
//  Lightweight AVPlayerLayer wrapper — NO system controls, NO AirPlay.
//  We draw our own overlay controls on top.
//

import SwiftUI
import AVFoundation

/// UIViewRepresentable that hosts an AVPlayerLayer for a given AVPlayer.
/// Uses `resizeAspect` so the video fills the bounds while preserving aspect.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerLayerUIView {
        let v = PlayerLayerUIView()
        v.playerLayer.player = player
        return v
    }

    func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerLayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        playerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
    }
}
