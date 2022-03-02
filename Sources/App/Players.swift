//
//  Players.swift
//  ConsoleKit
//
//  Created by Denis Koryttsev on 27.08.2020.
//

import Foundation
import ConsoleKit
#if os(macOS)
import AVFoundation
#endif

#if os(macOS)
typealias SystemPlayer = AVQueuePlayer
#else
final class SystemPlayer: Player {
    static var didPlayToEndTimeNotification: Notification.Name { Notification.Name("") }
    var name: String { "Undefined. Use alternative" }
    var currentTime: TimeInterval { 0 }
    var playingItemDuration: TimeInterval { 0 }
    func play() { fatalError("System player undefined. Use alternative") }
    func pause() {}
    func stop() {}
    func removeAllItems() {}
    func appendItem(_ url: URL) {}
}
#endif

protocol Player: AnyObject {
    static var didPlayToEndTimeNotification: Notification.Name { get }
    var name: String { get }
    var currentTime: TimeInterval { get }
    var playingItemDuration: TimeInterval { get }

    func play()
    func pause()
    func stop()
    func appendItem(_ url: URL)
    func removeAllItems()
}
struct PlayerBar: ActivityBar {
    weak var player: Player?

    var title: String
    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm:ss"
        return formatter
    }()

    init(title: String, player: Player) {
        self.title = title
        self.player = player
    }

    func renderActiveBar(tick: UInt, width: Int) -> ConsoleText {
        guard let player = player else { return "Stopped" }
        let duration = player.playingItemDuration
        let currentTime = player.currentTime
        let progress = currentTime / duration
        guard !progress.isNaN else { return "" }
        let current = min(max(progress, 0.0), 1.0)

        let left = Int(current * Double(ProgressBar.width))
        let right = ProgressBar.width - left

        var barComponents: [String] = []
        barComponents.append(timeFormatter.string(from: Date(timeIntervalSince1970: currentTime)))
        barComponents.append("[")
        barComponents.append(.init(repeating: "=", count: Int(left)))
        barComponents.append(.init(repeating: " ", count: Int(right)))
        barComponents.append("]")
        barComponents.append(timeFormatter.string(from: Date(timeIntervalSince1970: duration)))
        return barComponents.joined(separator: "").consoleText(.info)
    }
}

#if os(macOS)
extension AVQueuePlayer: Player {
    static var didPlayToEndTimeNotification: Notification.Name { .AVPlayerItemDidPlayToEndTime }
    var name: String {
        #if DEBUG
        return className
        #else
        return "System"
        #endif
    }
    var playingItemDuration: TimeInterval { currentItem?.asset.duration.seconds ?? 0 }
    var currentTime: TimeInterval { currentTime().seconds }
    func appendItem(_ url: URL) {
        currentItem.map(remove(_:))
        insert(AVPlayerItem(asset: AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/mp3"])), after: nil)
    }
    func stop() { pause() }
}
#endif

final class VLCPlayer {
    private let executablePath: URL

    private var currentProcess: Process?
    private var input: Pipe = Pipe()
    private var output: Pipe = Pipe()

    var error: Error?
    var currentItem: URL?

    init(url: URL) {
        self.executablePath = url
    }

    deinit {
        currentProcess?.terminationHandler = nil
        currentProcess?.terminate()
        currentProcess = nil
    }

    private func send(_ command: String) -> String? {
        let data = "\(command)\n".data(using: .utf8)!
        let result: Void?
        if #available(macOS 10.15.4, *) { result = try? input.fileHandleForWriting.write(contentsOf: data) }
        else { result = input.fileHandleForWriting.write(data) }
        return result.flatMap {
            let resData = output.fileHandleForReading.availableData
            return String(data: resData, encoding: .utf8)
        }
    }

    static let trimmingCharacters: CharacterSet = CharacterSet(charactersIn: "\r\n> ")
}
extension VLCPlayer: Player {
    static var didPlayToEndTimeNotification: Notification.Name { Notification.Name("VLCPlayerDidEndPlaying") }
    var name: String { "VLC" }
    var currentTime: TimeInterval {
        return currentProcess.flatMap { process -> TimeInterval? in
            guard process.isRunning else { return nil }
            let result = send("get_time").flatMap { val in
                TimeInterval(val.trimmingCharacters(in: VLCPlayer.trimmingCharacters))
            }
            return result
        } ?? 0
    }
    var playingItemDuration: TimeInterval {
        send("get_length").flatMap { val in
            TimeInterval(val.trimmingCharacters(in: VLCPlayer.trimmingCharacters))
        } ?? 0
    }

    func play() {
        do {
            if let process = self.currentProcess {
                guard process.isRunning else { return }
                process.resume()
            } else {
                guard let url = currentItem else { return }
                self.input = Pipe()
                self.output = Pipe()
                let process = Process()
                process.executableURL = executablePath
                process.arguments = ["-I", "rc", "--play-and-exit", url.absoluteString]
                process.standardInput = input
                process.standardOutput = output
                process.standardError = output
                process.terminationHandler = { [weak self] _ in
                    self?.currentProcess = nil
                    NotificationCenter.default.post(name: VLCPlayer.didPlayToEndTimeNotification, object: nil)
                }
                try process.run()
                self.currentProcess = process
            }
        } catch {
            self.error = error
        }
    }

    func pause() {
        currentProcess?.suspend()
    }

    func appendItem(_ url: URL) {
        self.currentItem = url
    }

    func stop() {
        currentProcess?.terminationHandler = nil
        currentProcess?.terminate()
        currentProcess = nil
    }
    func removeAllItems() {
        self.currentItem = nil
    }
}
extension VLCPlayer {
    convenience init(path: String?) {
        let executablePath: String
        if let p = path {
            executablePath = p
        } else {
            #if os(macOS)
            executablePath = "/Applications/VLC.app/Contents/MacOS/VLC"
            #else
            executablePath = "/usr/bin/vlc"
            #endif
        }
        self.init(url: URL(fileURLWithPath: executablePath))
    }
}
