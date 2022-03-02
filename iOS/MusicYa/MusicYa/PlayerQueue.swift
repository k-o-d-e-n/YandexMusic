//
//  PlayerQueue.swift
//  MusicYa
//
//  Created by Denis Koryttsev on 21.12.2020.
//

import Foundation
import YandexMusic
import YandexAuth

struct PlayerQueueSettings {
    var shuffled: Bool = false
    var reversed: Bool = false
    var repeated: Bool = false

    init() {}

    func apply<E>(for items: [E]) -> [E] {
        var itms = items
        if shuffled {
            itms = itms.shuffled()
        }
        if reversed {
            itms = itms.reversed()
        }
        return itms
    }
}

extension PlaylistChange.Diff {
    func apply<T>(for items: inout [T]) -> [T] {
        switch op {
        case .delete:
            guard let from = from, let to = to else { return [] }
            return (from ..< to).map { i in
                items.remove(at: i)
            }
        case .insert: return []
        }
    }
}
extension UserPlaylist {
    fileprivate func with(tracks: [TrackItem]) -> UserPlaylist {
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
            isPremiere: isPremiere,
            everPlayed: everPlayed,
            tracks: tracks
        )
    }
}

protocol QueueEditor {
    func change(_ diff: [PlaylistChange.Diff], completion: @escaping (Result<Void, Error>) -> Void)
}

protocol PlayerQueue: AnyObject {
    var id: String { get }
    var client: YandexMusic.Client { get }
    var cacheFolder: URL { get }

    var currentTrackIndex: Int? { get set }
    var tracks: [Track] { get }
    var settings: PlayerQueueSettings { get set }

    var editor: QueueEditor? { get }

    func prepare(completion: @escaping (Result<[Track], Error>) -> Void)
    func canAdvance(toTrackBy offset: Int) -> Bool
    func advance(toTrackBy offset: Int, completion: @escaping (Result<Track, Error>) -> Void)

    func willPlay()
    func willPlay(trackAt index: Int)
    func didPlay(trackAt index: Int, played playedSeconds: TimeInterval?)
    func didPlay()
}

extension PlayerQueue {
    var shouldPreloadTrackData: Bool { false }
    var currentTrack: Track? { currentTrackIndex.map({ tracks[$0] }) }
    var editor: QueueEditor? { nil }

    func canAdvance(toTrackBy offset: Int) -> Bool {
        return currentTrackIndex.map({
            settings.repeated ? true : tracks.indices.contains($0 + offset)
        }) == true
    }

    func advance(toTrackBy offset: Int, completion: @escaping (Result<Track, Error>) -> Void) {
        guard let currentIndex = currentTrackIndex else { return completion(.failure(NSError(domain: "no-index", code: 0, userInfo: nil))) }
        let nextIndex = settings.repeated ? tracks.cycledIndex(currentIndex, offsetBy: offset) : currentIndex + offset
        guard nextIndex >= 0 else { return completion(.failure(NSError(domain: "negative-index", code: 0, userInfo: nil))) }
        guard nextIndex < tracks.count else { return completion(.failure(NSError(domain: "out-of-bound-index", code: 0, userInfo: nil))) }

        currentTrackIndex = nextIndex
        let nextTrack = tracks[nextIndex]
        guard nextTrack.available else { return advance(toTrackBy: 1, completion: completion) }
        completion(.success(nextTrack))
    }

    @discardableResult
    func prepareCurrentTrack(completion: @escaping (Result<URL, Error>) -> Void) -> Progress? {
        guard let track = currentTrack else { completion(.failure(NSError(domain: "no-current-track", code: 0, userInfo: nil))); return nil }
        return prepareToPlay(track: track, completion: completion)
    }

    @discardableResult
    func prepare(at index: Int, completion: @escaping (Result<URL, Error>) -> Void) -> Progress? {
        let track = tracks[index]
        return prepareToPlay(track: track, completion: completion)
    }

    func willPlay() {}
    func willPlay(trackAt index: Int) {}
    func didPlay(trackAt index: Int, played playedSeconds: TimeInterval?) {}
    func didPlay() {}

    fileprivate func prepareToPlay(track: Track, completion: @escaping (Result<URL, Error>) -> Void) -> Progress? {
        do { try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true, attributes: nil) }
        catch { completion(.failure(error)); return nil }
        let cacheFile = cacheFolder.appendingPathComponent(track.downloadTrackID, isDirectory: false)
        guard !FileManager.default.fileExists(atPath: cacheFile.relativePath) else { completion(.success(cacheFile)); return nil }

        let progress = Progress(totalUnitCount: 10)
        client.downloadInfo(ofTrackWith: track.downloadTrackID) { (downloadInfo) in
            switch downloadInfo {
            case .success(let infos):
                guard let info = infos.first(where: { $0.codec == "mp3" }) ?? infos.first else {
                    return completion(Result<URL, Error>.failure(NSError(domain: "no-downloads", code: 0, userInfo: nil)))
                }
                self.load(info: info, cacheFile: cacheFile, progress: progress, completion: completion)
            case .failure(let error):
                return completion(.failure(error))
            }
        }
        .map({ infoTask in
            progress.addChild(infoTask.progress, withPendingUnitCount: shouldPreloadTrackData ? 2 : 5)
        })
        return progress
    }

    private func load(info: Track.DownloadInfo, cacheFile: URL, progress: Progress, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: info.downloadInfoUrl) else { return completion(.failure(NSError(domain: "bad-url", code: 0, userInfo: nil))) }

        if info.direct {
            guard shouldPreloadTrackData else { return completion(.success(url)) }
            let task = load(url, cacheFile: cacheFile, completion: completion)
            progress.addChild(task.i.progress, withPendingUnitCount: 8)
        } else {
            client.downloadURL(by: url, codec: info.codec) { [unowned self] (res) in
                guard shouldPreloadTrackData else { return completion(res) }
                guard case .success(let url) = res else { return completion(res) }
                let task = self.load(url, cacheFile: cacheFile, completion: completion)
                progress.addChild(task.i.progress, withPendingUnitCount: 6)
            }
            .map { (urlTask) -> Void in
                progress.addChild(urlTask.progress, withPendingUnitCount: shouldPreloadTrackData ? 2 : 5)
            }
        }
    }

    private func load(_ url: URL, cacheFile: URL, completion: @escaping (Result<URL, Error>) -> Void) -> (t: URLSessionTask, i: DownloadSession.TaskInfo) {
        // can be load through data task, because server returns data, but timeout error happened anyway
//        var bgTask: UIBackgroundTaskIdentifier = .invalid
//        bgTask = UIApplication.shared.beginBackgroundTask {
//            UIApplication.shared.endBackgroundTask(bgTask)
//            bgTask = .invalid
//        }
//        let urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: .infinity)
//        let task = URLSession.shared.downloadTask(with: urlRequest, completionHandler: { (fileUrl, response, error) in
//            UIApplication.shared.endBackgroundTask(bgTask)
//            bgTask = .invalid
//            if let fUrl = fileUrl {
//                do {
//                    try FileManager.default.copyItem(at: fUrl, to: cacheFile)
//                    completion(.success(cacheFile))
//                } catch {
//                    completion(.failure(NSError(domain: "cannot-open-file", code: 0, userInfo: nil)))
//                }
//            } else {
//                completion(.failure(error ?? NSError(domain: "cannot-download-file", code: 0, userInfo: nil)))
//            }
//        })
        let task = downloadSession.task(for: url, destinationURL: cacheFile, completion: completion)!
        task.t.resume()
        return task
    }

    fileprivate func didPlay(_ track: Track, fromPlaylist plId: String?, fromCache: Bool?, userID: Int?) {
        let duration = track.durationMs.map({ $0 / 1000 })
        let event = Client.PlayEvent(
            trackId: track.id, albumId: track.albums?.first?.id ?? 0, from: "YandexMusicAndroid/23020251",
            playlistId: plId, fromCache: fromCache, playId: "", uid: userID,
            timestamp: Date(), trackLength: duration, totalPlayed: duration, endPosition: duration,
            clientNow: Date()
        )
        client.sendPlay(event) { (result) in
            #if DEBUG && Xcode
            print("Did send play event with result", result)
            #endif
        }
    }
}
var downloadSession: DownloadSession = DownloadSession()

final class RadioQueue: PlayerQueue {
    private var batch: StationTracksResult?

    let station: RadioStation
    let client: YandexMusic.Client
    let cacheFolder: URL

    var currentTrackIndex: Int?
    var tracks: [Track] = []
    var settings: PlayerQueueSettings = .init() {
        didSet {
            let current = currentTrack
            tracks = settings.apply(for: batch?.sequence.map({ $0.track }) ?? [])
            if let track = current {
                currentTrackIndex = tracks.firstIndex(where: { $0.id == track.id })
            }
        }
    }
    var id: String {
        "\(station.id.type):\(station.id.tag)"
    }

    init(station: RadioStation, client: YandexMusic.Client, cacheFolder: URL) {
        self.station = station
        self.client = client
        self.cacheFolder = cacheFolder
    }

    func prepare(completion: @escaping (Result<[Track], Error>) -> Void) {
        client.queue(forStationWith: station.id, last: currentTrack?.id) { (result) in
            switch result {
            case .failure(let err): completion(.failure(err))
            case .success(let items):
                do {
                    self.batch = items
                    self.tracks = self.settings.apply(for: items.sequence.map({ $0.track }))
                    if self.shouldPreloadTrackData, FileManager.default.fileExists(atPath: self.cacheFolder.relativePath) {
                        let toRemoveFiles = try FileManager.default.contentsOfDirectory(atPath: self.cacheFolder.relativePath).filter({ n in !self.tracks.contains(where: { $0.downloadTrackID == n }) })
                        try toRemoveFiles.forEach { try FileManager.default.removeItem(at: self.cacheFolder.appendingPathComponent($0)) }
                    }
                    completion(.success(self.tracks))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    func canAdvance(toTrackBy offset: Int) -> Bool {
        currentTrackIndex.map({ offset > 0 ? true : offset >= -$0 }) == true
    }

    func advance(toTrackBy offset: Int, completion: @escaping (Result<Track, Error>) -> Void) {
        guard let currentIndex = currentTrackIndex else { return completion(.failure(NSError(domain: "no-index", code: 0, userInfo: nil))) }
        let nextIndex = currentIndex + offset
        guard nextIndex >= 0 else { return completion(.failure(NSError(domain: "negative-index", code: 0, userInfo: nil))) }
        guard nextIndex < tracks.count else {
            return prepare { (result) in
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let tracks):
                    guard tracks.count > 0 else { return completion(.failure(NSError(domain: "no-tracks", code: 0, userInfo: nil))) }
                    self.currentTrackIndex = 0
                    completion(.success(tracks[0]))
                }
            }
        }

        currentTrackIndex = nextIndex
        completion(.success(tracks[nextIndex]))
    }

    func willPlay() {
        let event = Client.FeedbackEvent(type: "radioStarted", timestamp: Date().timeIntervalSince1970, from: station.idForFrom, trackId: nil, totalPlayedSeconds: nil)
        _send(event: event)
    }

    func willPlay(trackAt index: Int) {
        let track = tracks[index]
        let event = Client.FeedbackEvent(type: "trackStarted", timestamp: Date().timeIntervalSince1970, from: station.idForFrom, trackId: track.id, totalPlayedSeconds: nil)
        _send(event: event, batchId: batch?.batchId)
    }

    func didPlay(trackAt index: Int, played playedSeconds: TimeInterval?) {
        let track = tracks[index]
        let event = Client.FeedbackEvent(type: "trackFinished", timestamp: Date().timeIntervalSince1970, from: station.idForFrom, trackId: track.id, totalPlayedSeconds: playedSeconds)
        _send(event: event, batchId: batch?.batchId)
    }

    func _send(event: Client.FeedbackEvent, batchId: String? = nil) {
        client.sendRadio(event: event, forStationWith: station.id, batchID: batchId) { (result: Result<String, Error>) in
            switch result {
            case .failure(let error): print(event.type, error)
            case .success(let ok): print(event.type, ok)
            }
        }
    }
}

final class UserPlaylistQueue: PlayerQueue {
    let userId: String
    var playlist: UserPlaylist
    let client: YandexMusic.Client
    let cacheFolder: URL

    var currentTrackIndex: Int?
    var tracks: [Track] = []
    var settings: PlayerQueueSettings = .init() {
        didSet { applySettings() }
    }
    var id: String { "\(playlist.kind)" }
    var editor: QueueEditor? { Editor(queue: self) }
    struct Editor: QueueEditor {
        let queue: UserPlaylistQueue
        func change(_ diff: [PlaylistChange.Diff], completion: @escaping (Result<Void, Error>) -> Void) {
            let change = PlaylistChange(kind: queue.playlist.kind, revision: queue.playlist.revision, diff: diff)
            queue.client.playlist(change: change, userID: queue.userId) { (result) in
                switch result {
                case .success(let playlist):
                    let removed = diff.flatMap({ ch in ch.apply(for: &self.queue.tracks) })
                    var oldTracks = self.queue.playlist.tracks ?? []
                    oldTracks.removeAll(where: { removed.contains($0.track) })
                    self.queue.playlist = playlist.with(tracks: oldTracks)
                    self.queue.applySettings()
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    init(ofUser userId: String, playlist: UserPlaylist, client: YandexMusic.Client, cacheFolder: URL) {
        self.userId = userId
        self.playlist = playlist
        self.client = client
        self.cacheFolder = cacheFolder
    }

    func prepare(completion: @escaping (Result<[Track], Error>) -> Void) {
        client.tracks(ofPlaylistWith: id, userID: userId) { (result) in
            switch result {
            case .failure(let err): completion(.failure(err))
            case .success(let items):
                do {
                    try self.updateTracks(items)
                    completion(.success(self.tracks))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    fileprivate func applySettings() {
        let current = currentTrack
        tracks = settings.apply(for: playlist.tracks?.map({ $0.track }) ?? [])
        if let track = current {
            currentTrackIndex = tracks.firstIndex(where: { $0.id == track.id })
        }
    }

    fileprivate func updateTracks(_ playlist: UserPlaylist) throws {
        self.playlist = playlist
        self.tracks = self.settings.apply(for: self.playlist.tracks?.map({ $0.track }) ?? [])
        if self.shouldPreloadTrackData, FileManager.default.fileExists(atPath: self.cacheFolder.relativePath) {
            let toRemoveFiles = try FileManager.default.contentsOfDirectory(atPath: self.cacheFolder.relativePath).filter({ n in !self.tracks.contains(where: { $0.downloadTrackID == n }) })
            try toRemoveFiles.forEach { try FileManager.default.removeItem(at: self.cacheFolder.appendingPathComponent($0)) }
        }
    }

    func didPlay(trackAt index: Int, played playedSeconds: TimeInterval?) {
        let track = tracks[index]
        didPlay(
            track,
            fromPlaylist: "\(playlist.kind)",
            fromCache: FileManager.default.fileExists(atPath: cacheFolder.appendingPathComponent(track.downloadTrackID).relativePath),
            userID: nil
        )
    }
}
final class FeedPlaylistQueue: PlayerQueue {
    private var _tracks: [Track] = []

    let playlist: FeedPlaylist
    let client: YandexMusic.Client
    let cacheFolder: URL

    var currentTrackIndex: Int?
    var tracks: [Track] = []
    var settings: PlayerQueueSettings = .init() {
        didSet {
            let current = currentTrack
            tracks = settings.apply(for: _tracks)
            if let track = current {
                currentTrackIndex = tracks.firstIndex(where: { $0.id == track.id })
            }
        }
    }
    var id: String { "\(playlist.kind)" }

    init(playlist: FeedPlaylist, client: YandexMusic.Client, cacheFolder: URL) {
        self.playlist = playlist
        self.client = client
        self.cacheFolder = cacheFolder
    }

    func prepare(completion: @escaping (Result<[Track], Error>) -> Void) {
        client.tracks(with: playlist.tracks?.map({ "\($0.id)" }) ?? []) { (result) in
            switch result {
            case .failure(let err): completion(.failure(err))
            case .success(let items):
                do {
                    self._tracks = items
                    self.tracks = self.settings.apply(for: items)
                    if self.shouldPreloadTrackData, FileManager.default.fileExists(atPath: self.cacheFolder.relativePath) {
                        let toRemoveFiles = try FileManager.default.contentsOfDirectory(atPath: self.cacheFolder.relativePath).filter({ n in !self.tracks.contains(where: { $0.downloadTrackID == n }) })
                        try toRemoveFiles.forEach { try FileManager.default.removeItem(at: self.cacheFolder.appendingPathComponent($0)) }
                    }
                    completion(.success(self.tracks))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    func didPlay(trackAt index: Int, played playedSeconds: TimeInterval?) {
        let track = tracks[index]
        didPlay(
            track,
            fromPlaylist: "\(playlist.kind)",
            fromCache: FileManager.default.fileExists(atPath: cacheFolder.appendingPathComponent(track.downloadTrackID).relativePath),
            userID: nil
        )
    }
}
final class LikedTracksQueue: PlayerQueue {
    private var _tracks: [Track] = []

    let userId: String
    let client: YandexMusic.Client
    let cacheFolder: URL

    var currentTrackIndex: Int?
    var tracks: [Track] = []
    var settings: PlayerQueueSettings = .init() {
        didSet {
            let current = currentTrack
            tracks = settings.apply(for: _tracks)
            if let track = current {
                currentTrackIndex = tracks.firstIndex(where: { $0.id == track.id })
            }
        }
    }
    var id: String { "app-liked-queue" }

    init(ofUser userId: String, client: YandexMusic.Client, cacheFolder: URL) {
        self.userId = userId
        self.client = client
        self.cacheFolder = cacheFolder
    }

    func prepare(completion: @escaping (Result<[Track], Error>) -> Void) {
        client.likedTracks(ofUserWith: userId) { (result1) in
            switch result1 {
            case .failure(let err): completion(.failure(err))
            case .success(let liked):
                self.client.tracks(with: liked.library.tracks.map({ "\($0.id)" })) { (result2) in
                    switch result2 {
                    case .failure(let err): completion(.failure(err))
                    case .success(let items):
                        do {
                            self._tracks = items
                            self.tracks = self.settings.apply(for: items)
                            if self.shouldPreloadTrackData, FileManager.default.fileExists(atPath: self.cacheFolder.relativePath) {
                                let toRemoveFiles = try FileManager.default.contentsOfDirectory(atPath: self.cacheFolder.relativePath).filter({ n in !self.tracks.contains(where: { $0.downloadTrackID == n }) })
                                try toRemoveFiles.forEach { try FileManager.default.removeItem(at: self.cacheFolder.appendingPathComponent($0)) }
                            }
                            completion(.success(self.tracks))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }

    func didPlay(trackAt index: Int, played playedSeconds: TimeInterval?) {
        let track = tracks[index]
        didPlay(
            track,
            fromPlaylist: nil,
            fromCache: FileManager.default.fileExists(atPath: cacheFolder.appendingPathComponent(track.downloadTrackID).relativePath),
            userID: nil
        )
    }
}
// TODO: Save track info with sound file to make possible to play offline
final class DownloadedTracksQueue: PlayerQueue {
    private var files: [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: cacheFolder.relativePath)) ?? []
    }
    private var _tracks: [Track] = []

    let client: YandexMusic.Client
    let cacheFolder: URL

    var currentTrackIndex: Int?
    var tracks: [Track] = []
    var settings: PlayerQueueSettings = .init() {
        didSet {
            let current = currentTrack
            tracks = settings.apply(for: _tracks)
            if let track = current {
                currentTrackIndex = tracks.firstIndex(where: { $0.id == track.id })
            }
        }
    }
    var id: String { "app-downloaded-queue" }

    init(client: YandexMusic.Client, cacheFolder: URL) {
        self.client = client
        self.cacheFolder = cacheFolder
    }

    func prepare(completion: @escaping (Result<[Track], Error>) -> Void) {
        client.tracks(with: files.compactMap({ $0.split(separator: ":").first.map(String.init) })) { (result1) in
            switch result1 {
            case .failure(let err): completion(.failure(err))
            case .success(let items):
                do {
                    self._tracks = items
                    self.tracks = self.settings.apply(for: items)
                    if self.shouldPreloadTrackData, FileManager.default.fileExists(atPath: self.cacheFolder.relativePath) {
                        let toRemoveFiles = try FileManager.default.contentsOfDirectory(atPath: self.cacheFolder.relativePath).filter({ n in !self.tracks.contains(where: { $0.downloadTrackID == n }) })
                        try toRemoveFiles.forEach { try FileManager.default.removeItem(at: self.cacheFolder.appendingPathComponent($0)) }
                    }
                    completion(.success(self.tracks))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
}
