//
//  Models.swift
//  YandexMusic
//
//  Created by Denis Koryttsev on 24.08.2020.
//

import Foundation

public struct LikedTracks: Codable {
    public let library: TrackList
}
public struct Feed: Codable {
    public let canGetMoreEvents: Bool
    public let pumpkin: Bool
    public let isWizardPassed: Bool
    public let generatedPlaylists: [GeneratedPlaylist]
    public let headlines: [String]
    public let today: String /// YYYY-MM-DD
    /// let days: [Day]

    public struct GeneratedPlaylist: Codable {
        public let type: String
        public let ready: Bool
        public let notify: Bool
        public let data: Playlist<Track>
        public let description: String?

        public struct Track: Codable {
            public let id: Int
            public let timestamp: Date
        }
    }

    public struct Day: Codable {
        let day: String /// YYYY-MM-DD.
        /// let events: [Event]
        /// let tracksToPlayWithAds: [TrackWithAds]
        let tracksToPlay: [Track]
    }
}
public typealias FeedPlaylist = Playlist<Feed.GeneratedPlaylist.Track>
public typealias UserPlaylist = Playlist<TrackItem>
public extension UserPlaylist {
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
public struct Playlist<TrackType>: Codable where TrackType: Codable {
    public let uid: Int
    public let kind: Int
    public let title: String
    public let trackCount: Int
    public let created: Date
    public let modified: Date?
    public let durationMs: Int
    public let isBanner: Bool
    public let isPremiere: Bool
    public let everPlayed: Bool?
    public let tracks: [TrackType]?

    public struct Cover: Codable {
        let type: String
        let itemsUri: [String]
        let custom: Bool
    }
}
public struct TrackList: Codable {
    public let uid: Int
    public let revision: Int
    public let tracks: [TrackShort]
}
public struct TrackShort: Codable {
    public let id: String
    public let timestamp: Date
    public let albumId: String?
    public let playCount: Int?
    public let recent: Bool?
    /// let chart: Chart
    public let track: Track?
}
public struct Track: Codable {
    public let id: String
    public let realId: String
    public let title: String
    public let available: Bool
    public let availableForPremiumUsers: Bool
    public let availableFullWithoutPermission: Bool
    public let durationMs: TimeInterval?
    public let fileSize: Int?
    public let major: Major?
    public let albums: [Album]?
    public let artists: [Artist]?

    public var downloadTrackID: String {
        albums?.first.map({ "\(id):\($0.id)" }) ?? id
    }

    public struct Major: Codable {
        let id: Int
        let name: String
    }

    public struct DownloadInfo: Codable {
        public let codec: String
        public let bitrateInKbps: Int
        public let gain: Bool
        public let preview: Bool
        public let downloadInfoUrl: String
        public let direct: Bool
    }
}
public struct TrackItem: Codable {
    public let id: Int
    public let track: Track

    public init(id: Int, track: Track) {
        self.id = id
        self.track = track
    }
}
public struct Album: Codable {
    public let id: Int
}
public struct Artist: Codable {
    public let id: Int
    public let name: String
    public let various: Bool
    public let composer: Bool
    public let cover: Cover?

    public struct Cover: Codable {
        let type: String
        let prefix: String
        let uri: String
    }
}
public struct Supplement: Codable {
    public let id: String
    public let lyrics: Lyrics
    /// let videos: VideoSupplement
    public let radioIsAvailable: Bool

    public struct Lyrics: Codable {
        public let id: Int
        public let lyrics: String
        public let hasRights: Bool
        public let fullLyrics: String
        public let showTranslation: Bool
        public let textLanguage: String?
        public let url: String?
    }
}
