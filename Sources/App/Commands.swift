//
//  Commands.swift
//  MusicYaConsole
//
//  Created by Denis Koryttsev on 26.08.2020.
//

import Foundation
import ConsoleKit
import YandexMusic

extension Track {
    var pageUrl: String? {
        albums?.first.map { "https://music.yandex.ru/album/\($0.id)/track/\(id)" }
    }
}

extension CommandGroup {
    func outContextHelp(_ console: Console)  {
        if self.commands.count > 0 {
            console.print()
            console.output("Context commands:".consoleText(.success))
            let padding = (commands.map { $0.key.count }.max() ?? 0) + 2
            for (key, command) in self.commands.sorted(by: { $0.key < $1.key }) {
                console.output(String(repeating: " ", count: padding - key.count) + "\(key): \(command.help)", style: .warning, newLine: true)
            }
        }
        console.print()
    }
}

struct AuthCommand: Command {
    struct Signature: CommandSignature {}

    var help: String { "Auth in application" }

    func run(using context: CommandContext, signature: Signature) throws {
        context.console.output("Username: ".consoleText(.info), newLine: false)
        let username = context.console.input()
        context.console.output("Password: ".consoleText(.info), newLine: false)
        let password = context.console.input(isSecure: true)

        let activity = context.console.loadingBar(title: "Processing...")
        let semaphore = DispatchSemaphore(value: 0)
        context.app.auth.auth(with: username, password: password) { result in
            switch result {
            case .failure(let error):
                activity.fail()
                context.console.error("Error: " + String(describing: error))
            case .success(let user):
                activity.succeed()
                #if DEBUG
                context.console.output([
                    ConsoleTextFragment(string: "UID: ", style: .plain),
                    ConsoleTextFragment(string: user.uid.map(String.init) ?? "undefined", style: .success)
                ])
                #else
                context.console.success("Ready!", newLine: true)
                #endif
            }
            semaphore.signal()
        }
        activity.start()
        let result = semaphore.wait(timeout: .now() + .seconds(10))
        switch result {
        case .success: break
        case .timedOut:
            activity.fail()
            context.console.warning("Time's out")
        }
    }
}
struct PlaylistCommand: Command {
    struct Signature: CommandSignature {
        @Flag(name: "play", short: "p", help: "Play playlist")
        var play: Bool

        @Flag(name: "show", short: nil, help: "Show playlist tracks")
        var show: Bool

        @Flag(name: "shuffle", short: "s", help: "Shuffle tracks")
        var shuffle: Bool

        @Flag(name: "reverse", short: "r", help: "Reverse tracks")
        var reverse: Bool

        @Flag(name: "feed", short: "f", help: "Feed playlists")
        var feed: Bool

        @Flag(name: "liked", short: "l", help: "Feed playlists")
        var liked: Bool
    }

    struct NextCommand: Command {
        struct Signature: CommandSignature {}
        var help: String { "Play next track" }

        func run(using context: CommandContext, signature: Signature) throws {
            context.app.playItem()
        }
    }
    struct PreviousCommand: Command {
        struct Signature: CommandSignature {}
        var help: String { "Play previous track" }

        func run(using context: CommandContext, signature: Signature) throws {
            context.app.playItem(by: -1)
        }
    }
    struct PauseCommand: Command {
        struct Signature: CommandSignature {}
        var help: String { "Pause track" }

        func run(using context: CommandContext, signature: Signature) throws {
            context.app.pause()
        }
    }
    struct ContinueCommand: Command {
        struct Signature: CommandSignature {}
        var help: String { "Continue play track" }

        func run(using context: CommandContext, signature: Signature) throws {
            context.app.play()
        }
    }
    struct StopCommand: Command {
        struct Signature: CommandSignature {}
        var help: String { "Stop playing playlist" }

        func run(using context: CommandContext, signature: Signature) throws {
            context.app.stopAndRemoveContext()
        }
    }
    struct PageCommand: Command {
        struct Signature: CommandSignature {}
        var help: String { "Open track page" }

        func run(using context: CommandContext, signature: Signature) throws {
            if let page = context.app.currentTrack?.pageUrl {
                let process = Process()
                #if os(macOS)
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                #else
                process.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
                #endif
                process.arguments = [page]
                try process.run()
            }
        }
    }

    var help: String { "Choose playlist" }

    func run(using context: CommandContext, signature: Signature) throws {
        let application = context.app
        let activity1 = context.console.loadingBar(title: "Playlists:")
        activity1.start()

        let activity2: ActivityIndicator<LoadingBar>
        let playlistResult: Result<UserPlaylist, Error>
        if signature.feed {
            let playlistsResult = application.feedPlaylists()

            guard case .success(let playlists) = playlistsResult else {
                activity1.fail()
                return context.console.error(String(describing: playlistsResult), newLine: true)
            }
            activity1.succeed()

            let chosenPlaylist = context.console.choose("Choose playlist", from: playlists) { item -> ConsoleText in
                item.title.consoleText(color: .white, background: nil, isBold: true) +
                (item.everPlayed == true ? "*".consoleText(color: .yellow, isBold: true) : "")
            }

            playlistResult = context.app.tracks(of: chosenPlaylist)
            activity2 = context.console.loadingBar(title: "Tracks:")
        } else if signature.liked {
            activity1.succeed()
            playlistResult = application.likedTracks()
            activity2 = context.console.loadingBar(title: "Tracks:")
        } else {
            let playlistsResult = application.playlists()

            guard case .success(let playlists) = playlistsResult else {
                activity1.fail()
                return context.console.error(String(describing: playlistsResult), newLine: true)
            }
            activity1.succeed()

            let chosenPlaylist = context.console.choose("Choose playlist", from: playlists) { item -> ConsoleText in
                item.title.consoleText(color: .blue, background: nil, isBold: true)
            }

            playlistResult = context.app.tracks(of: chosenPlaylist)
            activity2 = context.console.loadingBar(title: "Tracks:")
        }
        activity2.start()
        guard case .success(let playlist) = playlistResult else {
            activity2.fail()
            return context.console.error(String(describing: playlistResult), newLine: true)
        }
        activity2.succeed()

        if signature.play {
            let tracks = (playlist.tracks ?? []).map { (trackItem) in
                trackItem.track
            }
            application.runContext(
                Commands(
                    commands: [
                        "<<": PreviousCommand(), "||": PauseCommand(), ">": ContinueCommand(),
                        "[]": StopCommand(), ">>": NextCommand(), "p": PageCommand()
                    ],
                    defaultCommand: nil,
                    enableAutocomplete: false
                )
            )
            let playResult = application.play(tracks: signature.shuffle ? tracks.shuffled() : signature.reverse ? tracks.reversed() : tracks)
            guard case .success = playResult else {
                application.stopAndRemoveContext()
                return context.console.error(String(describing: playResult), newLine: true)
            }
        } else {
            context.console.output(context.console.center(playlist.title), style: .success)
            (playlist.tracks ?? []).forEach { (trackItem) in
                context.console.output((trackItem.track.artists?.first.map({ $0.name + " - " }) ?? "") + trackItem.track.title, style: .info, newLine: false)
                context.console.output(
                    (trackItem.track.pageUrl.map { " -> \($0)" } ?? "")
                        .consoleText(color: .custom(r: 25, g: 25, b: 25))
                )
            }
        }
    }
}
struct MeCommand: Command {
    struct Signature: CommandSignature {}

    var help: String { "Print current user info" }

    func run(using context: CommandContext, signature: Signature) throws {
        #if DEBUG
        let meMessage = context.app.auth.accessToken.map(String.init(describing:))
        #else
        let meMessage = context.app.auth.accessToken.flatMap({ $0.username })
        #endif
        context.console.info(meMessage ?? "User not found", newLine: true)
    }
}
struct HelpCommand: Command {
    struct Signature: CommandSignature {}

    var help: String { "Application help" }

    func run(using context: CommandContext, signature: Signature) throws {
        let app = context.app
        let width = context.console.size.width
        let title = "*** MusicYa - CLI for Yandex Music ***"
        let titleSpacing = String(repeating: " ", count: max(0, width - title.count) / 2)
        context.console.print()
        context.console.output(
            (titleSpacing + title + titleSpacing)
                .consoleText(color: .red, background: .brightYellow, isBold: true),
            newLine: true
        )
        context.console.output(context.console.center("v1.1").consoleText(color: .red))
        context.console.output("* Configuration *", style: .info, newLine: true)
        context.console.output(
            """
                Player: \(app.player.name)
                Cache: \(app.cacheFolder.relativePath)
            """,
            newLine: true
        )
        context.console.print()
        context.console.info("Usage: <executable> <CLIENT_ID[:CLIENT_SECRET]> [--options]", newLine: true)
        context.console.info("Run options:", newLine: true)
        context.console.print("    --vlc [path]", newLine: true)
        var helpContext = CommandContext(console: context.console, input: CommandInput(arguments: [context.input.executablePath[0]]))
        try context.app.commandGroup.outputHelp(using: &helpContext)
    }
}
struct ExitCommand: Command {
    struct Signature: CommandSignature {}

    var help: String { "Stop application" }

    func run(using context: CommandContext, signature: Signature) throws {
        context.app.shutdown()
    }
}
