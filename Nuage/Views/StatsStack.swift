//
//  StatsStack.swift
//  Nuage
//
//  Created by Laurin Brandner on 01.08.23.
//

import SwiftUI
import SoundCloud

struct StatsStack: View {
    
    private var track: Track
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "play.fill")
            Text(format(count: track.playbackCount))
            
            Spacer().frame(width: 2)
            
            Image(systemName: "heart.fill")
            Text(format(count: track.likeCount))
            
            Spacer().frame(width: 2)
            
            Image(systemName: "arrow.triangle.2.circlepath")
            Text(format(count: track.repostCount))
        }
    }
    
    init(for track: Track) {
        self.track = track
    }
    
}
