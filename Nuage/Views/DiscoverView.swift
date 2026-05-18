//
//  DiscoverView.swift
//  Nuage
//

import SwiftUI
import Combine
import SoundCloud

struct DiscoverView: View {

    @State private var selections = [Selection]()
    @State private var didLoad = false
    @State private var subscriptions = Set<AnyCancellable>()

    var body: some View {
        Group {
            if selections.isEmpty && !didLoad {
                ProgressView().progressViewStyle(.circular)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(selections) { selection in
                            SelectionRow(selection: selection)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !didLoad else { return }
        SoundCloud.shared.get(.mixedSelections(), limit: 10)
            .map { $0.collection }
            .replaceError(with: [])
            .receive(on: RunLoop.main)
            .sink { value in
                selections = value
                didLoad = true
            }
            .store(in: &subscriptions)
    }

}

private struct SelectionRow: View {

    var selection: Selection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selection.title)
                .font(.title2)
                .bold()
            if let description = selection.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(selection.items.uniqued(), id: \.uniqueID) { item in
                        switch item {
                        case .playlist(let playlist): PlaylistCard(playlist: playlist)
                        case .user(let user): UserCard(user: user)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

}

private let cardWidth: CGFloat = 160

private struct PlaylistCard: View {

    var playlist: AnyPlaylist

    var body: some View {
        NavigationLink(value: playlist) {
            VStack(alignment: .leading, spacing: 6) {
                RemoteImage(url: playlist.artworkURL, cornerRadius: 6)
                    .frame(width: cardWidth, height: cardWidth)
                Text(playlist.title)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if playlist.userPlaylist != nil {
                    Text(playlist.user.username)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

}

private struct UserCard: View {

    var user: User

    var body: some View {
        NavigationLink(value: user) {
            VStack(alignment: .leading, spacing: 6) {
                RemoteImage(url: user.avatarURL, cornerRadius: cardWidth / 2)
                    .frame(width: cardWidth, height: cardWidth)
                Text(user.username)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let followers = user.followerCount {
                    HStack(spacing: 2) {
                        Text(String(followers))
                        Image(systemName: "person.2.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

}

private extension AnyItem {

    // `id` collapses User and Playlist IDs into the same numeric namespace.
    // Prefix by kind so the dedupe and ForEach identity stay correct.
    var uniqueID: String {
        switch self {
        case .user(let user): return "user:\(user.id)"
        case .playlist(let playlist): return "playlist:\(playlist.id)"
        }
    }

}

private extension Array where Element == AnyItem {

    // The endpoint can repeat the same item in a row (e.g. "Recently Played"
    // returns the same mix once per play). Keep the first occurrence.
    func uniqued() -> [AnyItem] {
        var seen = Set<String>()
        return filter { seen.insert($0.uniqueID).inserted }
    }

}
