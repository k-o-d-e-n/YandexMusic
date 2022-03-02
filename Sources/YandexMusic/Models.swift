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
public struct PlaylistChange: Encodable {
    public let kind: Int
    public let revision: Int
    public let diff: [Diff]

    public init(kind: Int, revision: Int, diff: [Diff]) {
        self.kind = kind
        self.revision = revision
        self.diff = diff
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(revision, forKey: .revision)
        try container.encode(String(data: try JSONEncoder().encode(diff), encoding: .utf8), forKey: .diff)
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case revision
        case diff
    }

    public struct Diff: Codable {
        public let op: Operation
        public let at: Int?
        public let from: Int?
        public let to: Int?
        public let tracks: [TrackID]?

        public struct TrackID: Codable {
            public let id: String
            public let albumId: String

            public init(id: String, albumId: String) {
                self.id = id
                self.albumId = albumId
            }
        }

        public enum Operation: String, Codable {
            case insert
            case delete
        }

        public static func delete(_ index: Int) -> Diff {
            Diff(op: .delete, at: nil, from: index, to: index + 1, tracks: nil)
        }
        public static func delete(_ indexes: Range<Int>) -> Diff {
            Diff(op: .delete, at: nil, from: indexes.lowerBound, to: indexes.upperBound, tracks: nil)
        }
        public static func insert(_ tracks: [TrackID], at index: Int = 0) -> Diff {
            Diff(op: .insert, at: index, from: nil, to: nil, tracks: tracks)
        }
    }
}
public typealias FeedPlaylist = Playlist<Feed.GeneratedPlaylist.Track>
public typealias UserPlaylist = Playlist<TrackItem>
public struct Playlist<TrackType>: Codable where TrackType: Codable {
    public let uid: Int
    public let kind: Int
    public let title: String
    public let trackCount: Int
    public let revision: Int
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
    
    public init(
        uid: Int,
        kind: Int,
        title: String,
        trackCount: Int,
        revision: Int,
        created: Date,
        modified: Date?,
        durationMs: Int,
        isBanner: Bool,
        isPremiere: Bool,
        everPlayed: Bool?,
        tracks: [TrackType]?
    ) {
        self.uid = uid
        self.kind = kind
        self.title = title
        self.trackCount = trackCount
        self.revision = revision
        self.created = created
        self.modified = modified
        self.durationMs = durationMs
        self.isBanner = isBanner
        self.isPremiere = isPremiere
        self.everPlayed = everPlayed
        self.tracks = tracks
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
public struct Track: Codable, Equatable {
    public let id: String
    public let realId: String
    public let title: String
    public let available: Bool
    public let lyricsAvailable: Bool
    public let availableForPremiumUsers: Bool
    public let availableFullWithoutPermission: Bool
    public let durationMs: Int?
    public let fileSize: Int?
    public let major: Major?
    public let albums: [Album]?
    public let artists: [Artist]?
    public let coverUri: String?

    public var downloadTrackID: String {
        albums?.first.map({ "\(id):\($0.id)" }) ?? id
    }

    public func coverUrl(forImageSize size: Int) -> String? {
        coverUri.map({ "https://" + $0.replacingOccurrences(of: "%%", with: "\(size)x\(size)") })
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

    public static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
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
    public let title: String
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
    public let lyrics: Lyrics?
    public let videos: [VideoSupplement]?
    public let radioIsAvailable: Bool?

    public struct Lyrics: Codable {
        public let id: Int
        public let lyrics: String
        public let hasRights: Bool
        public let fullLyrics: String
        public let showTranslation: Bool
        public let textLanguage: String?
        public let url: String?
    }
    public struct VideoSupplement: Codable {
        /// URL на обложку видео.
        public let cover: String
        /// Сервис поставляющий видео.
        public let provider: String
        /// Название видео.
        public let title: String?
        /// Уникальный идентификатор видео на сервисе.
        public let providerVideoId: String?
        /// URL на видео.
        public let url: String?
        /// URL на видео, находящегося на серверах Яндекса.
        public let embedUrl: String?
        /// HTML тег для встраивания видео.
        public let embed: String?
    }
}
public struct RadioDashboard: Codable {
    public let dashboardId: String
    public let stations: [StationResult]
    public let pumpkin: Bool

    public struct StationResult: Codable {
        public let station: RadioStation
        /// public let settings: RotorSettings
        /// public let settings2: RotorSettings
        /// public let adParams: AdParams
        public let explanation: String?
        public let prerolls: [String]?
    }
}
public struct RadioStation: Codable {
    public let id: ID
    public let parentId: ID?
    public let name: String
    /// public let icon: Icon
    /// public let mtsIcon: Icon
    /// public let geocellIcon: Icon
    public let idForFrom: String
    /// public let restrictions: Restrictions
    /// public let restrictions2: Restrictions
    public let fullImageUrl: String?
    /// public let mtsFullImageUrl: String?

    public struct ID: Codable {
        public let type: String
        public let tag: String
    }
    public struct Icon: Codable {
        public let backgroundColor: String /// HEX
        public let imageUrl: String
    }
    public struct Restrictions: Codable {
        /// public let language: Enum
        /// public let diversity: Enum
        /// public let mood: DiscreteScale?
        /// public let energy: DiscreteScale?
        /// public let moodEnergy: Enum?
    }
}
public struct StationTracksResult: Codable {
    public let id: RadioStation.ID
    public let sequence: [SequenceItem]
    public let batchId: String
    public let pumpkin: Bool

    public struct SequenceItem: Codable {
        public let type: String
        public let track: Track
        public let liked: Bool
    }
}
