//
//  PlaybackState.swift
//  Nuage
//
//  Created on 22.07.26.
//

import Foundation
import AVFoundation
import Combine

class PlaybackState: ObservableObject {
    
    @Published var progress: TimeInterval = 0.0 {
        didSet {
            if shouldSeek {
                let time = CMTime(seconds: progress, preferredTimescale: 1)
                player?.seek(to: time)
                onSeek?(time)
            }
        }
    }
    @Published private(set) var isPlaying = false
    
    private var shouldSeek = true
    private weak var player: AVPlayer?
    private var subscriptions = Set<AnyCancellable>()
    private var timeObserver: Any?
    
    var onSeek: ((CMTime) -> ())?
    
    // MARK: - Initialization
    
    func attach(to player: AVPlayer) {
        self.player = player
        
        let interval = CMTime(value: 1, timescale: 1)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.shouldSeek = false
            self.progress = time.seconds
            self.shouldSeek = true
        }
        
        player.publisher(for: \.timeControlStatus)
            .map { $0 != .paused }
            .receive(on: RunLoop.main)
            .assign(to: \.isPlaying, on: self)
            .store(in: &subscriptions)
    }
    
    // MARK: - Seeking
    
    func seekIfNeeded() {
        guard shouldSeek, let player = player else { return }
        let time = CMTime(seconds: progress, preferredTimescale: 1)
        player.seek(to: time)
        onSeek?(time)
    }
    
    func resetProgress() {
        shouldSeek = false
        progress = 0
        shouldSeek = true
    }
    
}
