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
            revision: playlist.revision,
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
            revision: playlist.revision,
            created: Date(),
            modified: Date(),
            durationMs: 0,
            isBanner: false,
            isPremiere: false,
            everPlayed: true,
            tracks: tracks
        )
    }

    func shuffled() -> UserPlaylist {
        UserPlaylist(
            uid: uid,
            kind: kind,
            title: title,
            trackCount: trackCount,
            revision: revision,
            created: created,
            modified: modified,
            durationMs: durationMs,
            isBanner: isBanner,
            isPremiere: isBanner,
            everPlayed: everPlayed,
            tracks: tracks?.shuffled()
        )
    }
    func reversed() -> UserPlaylist {
        UserPlaylist(
            uid: uid,
            kind: kind,
            title: title,
            trackCount: trackCount,
            revision: revision,
            created: created,
            modified: modified,
            durationMs: durationMs,
            isBanner: isBanner,
            isPremiere: isBanner,
            everPlayed: everPlayed,
            tracks: tracks?.reversed()
        )
    }
}

extension Track {
    var pageUrl: String? {
        albums?.first.map { "https://music.yandex.ru/album/\($0.id)/track/\(id)" }
    }

    var activityTitle: String {
        (artists?.first.map({ $0.name + " - " }) ?? "") + title
    }
}

