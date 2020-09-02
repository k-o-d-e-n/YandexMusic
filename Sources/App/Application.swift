//
//  Application.swift
//  MusicYaConsole
//
//  Created by Denis Koryttsev on 26.08.2020.
//

import Foundation
import YandexMusic
import YandexAuth
import ConsoleKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class CommandRunner {
    let queue: DispatchQueue?
    let commands: CommandGroup
    unowned let application: Application
    var isRunning: Bool = false
    let semaphore = DispatchSemaphore(value: 0)

    fileprivate init(queue: DispatchQueue?, application: Application, commands: CommandGroup) {
        self.commands = commands
        self.queue = queue
        self.application = application
        application.commandRunner = self
    }

    func run() {
        isRunning = true
        if let q = queue {
            q.async(execute: _run)
        } else {
            _run()
        }
    }

    func stop(_ completion: (() -> Void)? = nil) {
        if let q = queue {
            q.async {
                self.isRunning = false
                self.application.commandRunner = nil
                completion?()
            }
        } else {
            isRunning = false
            application.commandRunner = nil
            completion?()
        }
    }

    func stopAndWait() {
        stop()
        semaphore.wait()
    }

    private func _run() {
        while isRunning {
            commands.waitCommand(application)
        }
        semaphore.signal()
    }
}
extension AnyCommand {
    func waitCommand(_ application: Application, arguments: [String] = []) {
        guard let console = application.console else { return }
        var arguments = arguments
        if arguments.isEmpty {
            if let commandline = application.commandRunner != nil ? readLine(strippingNewline: true) : console.ask("") {
                arguments = commandline.split(separator: " ").map(String.init)
            }
        }
        arguments = [CommandLine.arguments[0]] + arguments
        guard arguments.count > 1 else {
            do {
                let ctx = CommandContext(application: application, input: CommandInput(arguments: arguments + ["me"]))
                try console.run(self, with: ctx)
            } catch {
                console.error("\(error)")
            }
            return
        }

        let ctx = CommandContext(application: application, input: CommandInput(arguments: arguments))
        do {
            try console.run(self, with: ctx)
        } catch CommandError.missingCommand {
        } catch let error {
            console.error("\(error)")
        }
    }
}

final class Application {
    private var notificationObserver: NSObjectProtocol?
    fileprivate var commandRunner: CommandRunner?
    private var userPlaylists: [UserPlaylist]?
    private var currentPlaylist: [Track]?
    private var playingTrackIndex: Int?
    private var playerProgress: ActivityIndicator<PlayerBar>?
    private var pauseGroup: DispatchGroup?

    let name: String
    let player: Player
    let commandGroup: CommandGroup
    let auth: TokenProvider

    var isRunning: Bool = false
    weak var console: Console?

    lazy var client: Client = Client(
        .init(
            url: URL(string: "https://api.music.yandex.net")!,
            tokenProvider: auth
        )
    )

    var isPlayingMode: Bool { playingTrackIndex != nil }
    var cacheFolder: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(name, isDirectory: true)
    }
    var currentTrack: Track? { playingTrackIndex.flatMap({ currentPlaylist?[$0] }) }

    struct Signature: CommandSignature {
        @Argument(name: "client", help: "Client ID and Secret")
        var client: String
        @Option(name: "vlc", short: nil, help: "VLC player path", completion: .files())
        var vlc: String?
    }

    init(signature: Signature) {
        self.name = CommandLine.arguments[0].split(separator: "/").last.map(String.init) ?? "MusicYa"
        self.auth = TokenProvider(clientInfo: signature.client, storage: Application.tokenStorage(name))

        CommandLine.arguments.removeAll(where: { $0 == signature.client })
        if signature.$vlc.isPresent {
            CommandLine.arguments.removeAll(where: { $0 == "--vlc" })
            self.player = signature.vlc.map { path in
                CommandLine.arguments.removeAll(where: { $0 == path })
                return VLCPlayer(path: path)
            } ?? VLCPlayer(path: nil)
        } else {
            self.player = SystemPlayer()
        }

        var commands = Commands(enableAutocomplete: true)
        commands.use(MeCommand(), as: "me")
        commands.use(PlaylistCommand(), as: "playlist")
        commands.use(HelpCommand(), as: "help")
        commands.use(ExitCommand(), as: "exit")
        self.commandGroup = commands.group()
        
        self.notificationObserver = NotificationCenter.default.addObserver(forName: type(of: player).didPlayToEndTimeNotification, object: nil, queue: nil) { [unowned self] _ in
            self.didEndPlaying()
        }
    }

    deinit {
        notificationObserver.map(NotificationCenter.default.removeObserver)
    }

    private static func tokenStorage(_ appName: String) -> TokenProvider.SecretStorage {
        #if os(macOS)
        #if DEBUG || Xcode
        return .userDefaults("access_token")
        #else
        return .keychain("com.\(appName).access")
        #endif
        #else
        return .file(cacheFolder(name: appName).appendingPathComponent("access", isDirectory: false))
        #endif
    }

    private static func cacheFolder(name: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(name, isDirectory: true)
    }

    func run(in console: Console) throws {
        console.output(console.center("Welcome to MusicYa!"), style: .info, newLine: true)
        self.isRunning = true
        self.console = console

        var initialArgs = Array(CommandLine.arguments.dropFirst())
        while isRunning {
            guard let _ = auth.currentToken else {
                let input = CommandInput(arguments: CommandLine.arguments)
                try console.run(AuthCommand(), with: CommandContext(application: self, input: input))
                continue
            }
            if isPlayingMode {
                pauseGroup?.wait()
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
                continue
            }

            if let runner = commandRunner {
                console.popEphemeral()
                runner.stopAndWait()
            } else {
                commandGroup.waitCommand(self, arguments: initialArgs)
            }
            initialArgs.removeAll()
        }
    }

    func shutdown() {
        player.stop()
        self.isRunning = false
    }

    func runContext(_ commands: Commands, on queue: DispatchQueue? = nil) {
        guard commandRunner == nil else { fatalError("Context runner already started") }
        let group = commands.group()
        console.map { (console) -> Void in
            console.pushEphemeral()
            group.outContextHelp(console)
        }
        let runner = CommandRunner(queue: queue ?? .global(qos: .userInteractive), application: self, commands: group)
        self.commandRunner = runner
        runner.run()
    }
}
extension Application {
    func stopAndRemoveContext() {
        let semaphore = DispatchSemaphore(value: 0)
        stop()
        commandRunner?.stop {
            try? FileHandle.standardInput.write(contentsOf: "\n".data(using: .utf8)!)
            self.playingTrackIndex = nil
            semaphore.signal()
        }
        semaphore.wait()
    }

    func play() {
        pauseGroup?.leave()
        pauseGroup = nil
        player.play()
        playerProgress?.activity.title = "Playing"
    }

    func pause() {
        player.pause()
        playerProgress?.activity.title = "Paused"
        pauseGroup = DispatchGroup()
        pauseGroup?.enter()
    }

    func stop() {
        pauseGroup?.leave()
        pauseGroup = nil
        self.playerProgress?.succeed()
        self.playerProgress = nil
        player.stop()
    }

    func playItem(by offset: Int = 1) {
        stop()
        guard let currentIndex = playingTrackIndex else { return }
        let nextIndex = currentIndex + offset
        guard currentPlaylist!.count > nextIndex, nextIndex > -1 else {
            stopAndRemoveContext()
            return
        }
        _ = play(track: currentPlaylist![nextIndex], index: nextIndex)
    }

    func didEndPlaying() {
        playItem()
    }

    func likedTracks() -> Result<UserPlaylist, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var result1: Result<LikedTracks, Error>?
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        client.callAPI("users", auth.accessToken!.username!, "likes", "tracks", decoder: decoder) { (result: Result<LikedTracks, Error>) in
            result1 = result
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + .seconds(10)) == .timedOut {
            result1 = .failure(NSError(domain: "timeout", code: 0, userInfo: nil))
        }
        return result1!.flatMap { (likedTracks) -> Result<UserPlaylist, Error> in
            self.tracks(of: likedTracks.library)
        }.flatMapError({ .failure($0) })
    }

    func feedPlaylists() -> Result<[FeedPlaylist], Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var playlists: Result<[FeedPlaylist], Error>?
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        client.callAPI("feed", decoder: decoder) { (result: Result<Feed, Error>) in
            playlists = result.map({ $0.generatedPlaylists.map({ $0.data }) })
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + .seconds(10)) == .timedOut {
            playlists = .failure(NSError(domain: "timeout", code: 0, userInfo: nil))
        }
        return playlists!
    }

    func playlists(ofUser username: String? = nil) -> Result<[UserPlaylist], Error> {
        guard let playlists = userPlaylists else {
            let semaphore = DispatchSemaphore(value: 0)
            var playlists: Result<[UserPlaylist], Error>?
            client.playlists(ofUserWith: username ?? auth.username) { (result) in
                playlists = result
                semaphore.signal()
            }
            if semaphore.wait(timeout: .now() + .seconds(10)) == .timedOut {
                playlists = .failure(NSError(domain: "timeout", code: 0, userInfo: nil))
            }

            return playlists!
        }
        return .success(playlists)
    }

    func tracks(of playlist: TrackList) -> Result<UserPlaylist, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var tracks: Result<UserPlaylist, Error>?
        var requestPlaceholder = URLRequest(
            url: URL(string: "http://placeholder.com?trackIds=" + (playlist.tracks.map({ "\($0.id)" })).joined(separator: ","))!
        )
        requestPlaceholder.httpMethod = "POST"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        client.callAPI("tracks", placeholder: requestPlaceholder) { (result: Result<[Track], Error>) in
            tracks = result.map({ tracks in
                UserPlaylist(playlist: playlist, title: "Liked tracks", with: zip(playlist.tracks, tracks).map({ TrackItem(id: Int($0.id) ?? -1, track: $1) }))
            })
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + .seconds(30)) == .timedOut {
            tracks = .failure(NSError(domain: "timeout", code: 0, userInfo: nil))
        }

        return tracks!
    }

    func tracks(of playlist: FeedPlaylist) -> Result<UserPlaylist, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var tracks: Result<UserPlaylist, Error>?
        var requestPlaceholder = URLRequest(
            url: URL(string: "http://placeholder.com?trackIds=" + (playlist.tracks?.map({ "\($0.id)" }) ?? []).joined(separator: ","))!
        )
        requestPlaceholder.httpMethod = "POST"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        client.callAPI("tracks", placeholder: requestPlaceholder) { (result: Result<[Track], Error>) in
            tracks = result.map({ tracks in
                UserPlaylist(feed: playlist, with: zip(playlist.tracks ?? [], tracks).map({ TrackItem(id: $0.id, track: $1) }))
            })
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + .seconds(10)) == .timedOut {
            tracks = .failure(NSError(domain: "timeout", code: 0, userInfo: nil))
        }

        return tracks!
    }

    func tracks(of playlist: UserPlaylist, user username: String? = nil) -> Result<UserPlaylist, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var tracks: Result<UserPlaylist, Error>?
        client.tracks(ofPlaylistWith: "\(playlist.kind)", userID: username ?? auth.username) { (result) in
            tracks = result
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + .seconds(10)) == .timedOut {
            tracks = .failure(NSError(domain: "timeout", code: 0, userInfo: nil))
        }

        return tracks!
    }

    func play(tracks: [Track]) -> Result<ActivityIndicator<PlayerBar>?, Error> {
        self.currentPlaylist = tracks
        player.stop()
        player.removeAllItems()
        guard tracks.count > 0 else { return .success(nil) }

        return play(track: tracks[0], index: 0)
    }

    func play(track: Track, index: Int) -> Result<ActivityIndicator<PlayerBar>?, Error> {
        let tracksFolder = URL(fileURLWithPath: cacheFolder.relativePath, isDirectory: true)
            .appendingPathComponent("tracks", isDirectory: true)
        do { try FileManager.default.createDirectory(at: tracksFolder, withIntermediateDirectories: true, attributes: nil) }
        catch { return .failure(error) }
        let cacheFile = tracksFolder.appendingPathComponent(track.downloadTrackID, isDirectory: false)
        guard FileManager.default.fileExists(atPath: cacheFile.relativePath) else {
            let activity = console?.loadingBar(title: "Preparing...")
            activity?.start()
            return prepareToPlay(track: track).flatMap({ infos in
                guard let info = infos.first(where: { $0.codec == "mp3" }) ?? infos.first else { return .failure(NSError(domain: "no-downloads", code: 0, userInfo: nil)) }
                return load(info: info, cacheFile: cacheFile).map({ url in
                    activity?.succeed()
                    self.playingTrackIndex = index
                    return play(url, title: (track.artists?.first.map({ $0.name + " - " }) ?? "") + track.title)
                })
            })
            .mapError { (err) -> Error in
                activity?.fail()
                return err
            }
        }
        self.playingTrackIndex = index
        return .success(play(cacheFile, title: track.title))
    }

    func play(_ url: URL, title: String) -> ActivityIndicator<PlayerBar>? {
        player.appendItem(url)
        player.play()
        self.playerProgress = console.map { PlayerBar(title: "Playing: " + title, player: player).newActivity(for: $0) }
        playerProgress?.start(refreshRate: 1000)
        return playerProgress
    }

    func prepareToPlay(track: Track) -> Result<[Track.DownloadInfo], Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[Track.DownloadInfo], Error>?
        client.downloadInfo(ofTrackWith: track.downloadTrackID) { (res) in
            result = res
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + .seconds(10)) == .timedOut {
            result = .failure(NSError(domain: "timeout", code: 0, userInfo: nil))
        }
        return result!
    }

    private func load(info: Track.DownloadInfo, cacheFile: URL) -> Result<URL, Error> {
        guard let url = URL(string: info.downloadInfoUrl) else { return .failure(NSError(domain: "bad-url", code: 0, userInfo: nil)) }

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<URL, Error>?
        var timeout: Int = .max
        if info.direct {
            result = load(url, cacheFile: cacheFile)
            semaphore.signal()
        } else {
            timeout = 180
            client.downloadURL(by: url, codec: info.codec) { [unowned self] (res) in
                DispatchQueue.global(qos: .userInitiated).async {
                    result = res.flatMap({ self.load($0, cacheFile: cacheFile) })
                    semaphore.signal()
                }
            }
        }
        if semaphore.wait(timeout: .now() + .seconds(timeout)) == .timedOut {
            result = .failure(NSError(domain: "timeout", code: 0, userInfo: nil))
        }
        return result!
    }

    private func load(_ url: URL, cacheFile: URL) -> Result<URL, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<URL, Error>?
        let task = URLSession.shared.downloadTask(with: url, completionHandler: { (fileUrl, response, error) in
            if let fUrl = fileUrl {
                do {
                    try FileManager.default.copyItem(at: fUrl, to: cacheFile)
                    result = .success(cacheFile)
                } catch {
                    result = .failure(NSError(domain: "cannot-open-file", code: 0, userInfo: nil))
                }
            } else {
                result = .failure(error ?? NSError(domain: "cannot-download-file", code: 0, userInfo: nil))
            }
            semaphore.signal()
        })
        task.resume()
        if semaphore.wait(timeout: .now() + .seconds(120)) == .timedOut {
            result = .failure(NSError(domain: "timeout", code: 0, userInfo: nil))
        }
        return result!
    }

    final class TokenProvider: AccessTokenProvider {
        typealias AccessToken = YandexAuth.AccessToken
        let auth: YandexAuth
        let storage: SecretStorage
        var accessToken: AccessToken?
        var currentToken: String? {
            accessToken?.value
        }
        var username: String { accessToken?.username ?? "" }

        enum SecretStorage {
            case file(URL)
            #if os(macOS)
            case keychain(String)
            #endif
            /// Debug only
            @available(macOS 10.10, *)
            case userDefaults(String)
        }

        init(clientInfo: String, storage: SecretStorage) {
            self.storage = storage
            let client = clientInfo.split(separator: ":").map(String.init)
            self.auth = YandexAuth(clientID: client[0], secret: client.count > 1 ? client[1] : nil)

            var data: Data?
            switch storage {
            case .file(let tokenFile):
                if FileManager.default.fileExists(atPath: tokenFile.relativePath) {
                    data = try? Data(contentsOf: tokenFile)
                }
            #if os(macOS)
            case .keychain(let key):
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: key,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                    kSecReturnData as String: kCFBooleanTrue as Any
                ]
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                if status == errSecSuccess {
                    data = result as? Data
                }
            #endif
            case .userDefaults(let key): data = UserDefaults.standard.data(forKey: key)
            }
            self.accessToken = data.map { val in
                try! JSONDecoder().decode(AccessToken.self, from: val)
            }
        }

        func getAccessToken(_ completion: @escaping (Result<String, Error>) -> Void) {
            guard currentToken == nil else { return completion(.success(currentToken!)) }
            completion(.failure(NSError(domain: "no-token", code: 0, userInfo: nil)))
        }

        enum AuthError: Error {
            case tokenProcessingFails
        }

        func auth(with username: String, password: String, completion: @escaping (Result<AccessToken, Error>) -> Void) {
            let storage = self.storage
            auth.auth(with: username, password: password) { res in
                switch res {
                case .success(let token):
                    let accessToken = AccessToken(value: token.value, expired: token.expired, type: token.tokenType, uid: token.uid, username: username)
                    self.accessToken = accessToken
                    let data = try! JSONEncoder().encode(accessToken)
                    switch storage {
                    case .file(let fileUrl):
                        if !FileManager.default.createFile(atPath: fileUrl.relativePath, contents: data, attributes: [.posixPermissions : 0o700]) {
                            return completion(.failure(AuthError.tokenProcessingFails))
                        }
                    #if os(macOS)
                    case .keychain(let key):
                        let addquery: [String: Any] = [
                            kSecClass as String: kSecClassGenericPassword,
                            kSecAttrAccount as String: key,
                            kSecValueData as String: data
                        ]
                        let status = SecItemAdd(addquery as CFDictionary, nil)
                        guard status == errSecSuccess else { return completion(.failure(AuthError.tokenProcessingFails)) }
                    #endif
                    case .userDefaults(let key): UserDefaults.standard.set(data, forKey: key)
                    }
                case .failure: break
                }
                completion(res.mapError({ $0 }))
            }
        }
    }
}
extension CommandContext {
    var app: Application { return userInfo["app"] as! Application }

    init(application: Application, input: CommandInput) {
        guard let console = application.console else { fatalError("Application must be running") }
        self.init(console: console, input: input)
        self.userInfo["app"] = application
    }
}
