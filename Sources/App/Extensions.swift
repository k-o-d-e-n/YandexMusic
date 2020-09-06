//
//  Extensions.swift
//  MusicYa
//
//  Created by Denis Koryttsev on 05.09.2020.
//

import Foundation
import YandexMusic

extension UserPlaylist {
    init(feed playlist: FeedPlaylist, with tracks: [TrackItem]?) {
        self = UserPlaylist(
            uid: playlist.uid,
            kind: playlist.kind,
            title: playlist.title,
            trackCount: playlist.trackCount,
            created: playlist.created,
            modified: playlist.modified,
            durationMs: playlist.durationMs,
            isBanner: playlist.isBanner,
            isPremiere: playlist.isPremiere,
            everPlayed: playlist.everPlayed,
            tracks: tracks
        )
    }
    init(playlist: TrackList, title: String, with tracks: [TrackItem]) {
        self = UserPlaylist(
            uid: playlist.uid,
            kind: 0,
            title: title,
            trackCount: tracks.count,
            created: Date(),
            modified: Date(),
            durationMs: 0,
            isBanner: false,
            isPremiere: false,
            everPlayed: true,
            tracks: tracks
        )
    }
}
