//
//  PreloadManager.swift
//  Nuage
//
//  Created on 22.07.26.
//

import Foundation
import AVFoundation
import Combine
import SoundCloud

class PreloadManager {
    
    private let lookahead = 15
    private let timeout: Int = 10
    
    private var cachedAssets = [String: AVURLAsset]()
    private(set) var unplayableTracks = Set<String>()
    
    private var preloadSubscriptions = [String: AnyCancellable]()
    
    // MARK: - Preloading
    
    func preload(queue: [Track], queueOrder: [Int], from startIndex: Int) {
        guard startIndex < queueOrder.count else { return }
        
        let endIndex = min(startIndex + lookahead, queueOrder.count)
        guard endIndex > startIndex else { return }
        
        let upcomingIndices = (startIndex..<endIndex)
        let upcomingTracks = upcomingIndices.map { queue[queueOrder[$0]] }
        
        // Cancel preloads for tracks no longer in the lookahead window
        let upcomingIDs = Set(upcomingTracks.map { $0.id })
        for id in preloadSubscriptions.keys where !upcomingIDs.contains(id) {
            preloadSubscriptions[id]?.cancel()
            preloadSubscriptions.removeValue(forKey: id)
        }
        
        for track in upcomingTracks {
            guard !unplayableTracks.contains(track.id),
                  cachedAssets[track.id] == nil,
                  preloadSubscriptions[track.id] == nil else { continue }
            
            let subscription = track.prepare()
                .timeout(.seconds(timeout), scheduler: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    if case .failure = completion {
                        self.unplayableTracks.insert(track.id)
                    }
                    self.preloadSubscriptions.removeValue(forKey: track.id)
                }, receiveValue: { [weak self] asset in
                    guard let self = self else { return }
                    // Validate the asset is actually loadable
                    asset.loadValuesAsynchronously(forKeys: ["playable", "tracks"]) {
                        var error: NSError?
                        let playableStatus = asset.statusOfValue(forKey: "playable", error: &error)
                        let tracksStatus = asset.statusOfValue(forKey: "tracks", error: &error)
                        DispatchQueue.main.async {
                            if playableStatus == .loaded && tracksStatus == .loaded && asset.isPlayable {
                                self.cachedAssets[track.id] = asset
                            } else {
                                self.unplayableTracks.insert(track.id)
                            }
                        }
                    }
                })
            
            preloadSubscriptions[track.id] = subscription
        }
    }
    
    // MARK: - Access
    
    func asset(for track: Track) -> AVURLAsset? {
        return cachedAssets[track.id]
    }
    
    func isUnplayable(_ track: Track) -> Bool {
        return unplayableTracks.contains(track.id)
    }
    
    func markUnplayable(_ track: Track) {
        unplayableTracks.insert(track.id)
    }
    
    // MARK: - Cleanup
    
    func evict(before index: Int, queue: [Track], queueOrder: [Int]) {
        guard index > 0 else { return }
        let pastIndices = (0..<index)
        let pastIDs = Set(pastIndices.map { queue[queueOrder[$0]].id })
        
        for id in pastIDs {
            cachedAssets.removeValue(forKey: id)
        }
    }
    
    func reset() {
        for (_, sub) in preloadSubscriptions {
            sub.cancel()
        }
        preloadSubscriptions.removeAll()
        cachedAssets.removeAll()
        unplayableTracks.removeAll()
    }
    
}
