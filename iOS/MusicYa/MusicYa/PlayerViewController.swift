//
//  RadioViewController.swift
//  MusicYa
//
//  Created by Denis Koryttsev on 24.11.2020.
//

import UIKit
import YandexMusic
import AVFoundation
import MediaPlayer
import WebKit

extension UILayoutGuide {
    @objc func layout() {}
}

extension UIView {
    func updateLayoutGuides() {
        layoutGuides.forEach { lg in
            lg.layout()
        }
    }
}
extension AVPlayer {
    @objc func playAction() -> MPRemoteCommandHandlerStatus {
        guard timeControlStatus != .playing else { return .commandFailed }
        play()
        return .success
    }
    @objc func pauseAction() -> MPRemoteCommandHandlerStatus {
        guard timeControlStatus == .playing else { return .commandFailed }
        pause()
        return .success
    }
    @objc func toggleAction() -> MPRemoteCommandHandlerStatus {
        if timeControlStatus == .playing { pause() }
        else { play() }
        return .success
    }
}

final class PlaybackLayout: UILayoutGuide {
    lazy var vibrancyView1: UIVisualEffectView = UIVisualEffectView(autolayout: true).add(to: backgroundView.contentView) { vw in
        if #available(iOS 13.0, *) {
            vw.effect = UIVibrancyEffect(blurEffect: backgroundView.effect as! UIBlurEffect)
        }
        _ = UILabel(autolayout: true).add(to: vw.contentView) { bv in
            bv.text = "◀︎"
            NSLayoutConstraint.activate([
                bv.trailingAnchor.constraint(equalTo: vw.centerXAnchor, constant: -35),
                bv.centerYAnchor.constraint(equalTo: vw.centerYAnchor),
            ])
        }
        _ = UILabel(autolayout: true).add(to: vw.contentView) { bv in
            bv.text = "▶︎"
            NSLayoutConstraint.activate([
                bv.leadingAnchor.constraint(equalTo: vw.centerXAnchor, constant: 35),
                bv.centerYAnchor.constraint(equalTo: vw.centerYAnchor),
            ])
        }
        NSLayoutConstraint.activate(vw.constraints(equalTo: backgroundView.contentView))
    }
    lazy var vibrancyView2: UIVisualEffectView = UIVisualEffectView(autolayout: true).add(to: backgroundView.contentView) { vw in
        vw.isHidden = true
        if #available(iOS 13.0, *) {
            vw.effect = UIVibrancyEffect(blurEffect: backgroundView.effect as! UIBlurEffect)
        }
        _ = UILabel(autolayout: true).add(to: vw.contentView) { bv in
            bv.text = "◀︎◀︎"
            NSLayoutConstraint.activate([
                bv.trailingAnchor.constraint(equalTo: vw.centerXAnchor, constant: -35),
                bv.centerYAnchor.constraint(equalTo: vw.centerYAnchor),
            ])
        }
        _ = UILabel(autolayout: true).add(to: vw.contentView) { bv in
            bv.text = "▶︎▶︎"
            NSLayoutConstraint.activate([
                bv.leadingAnchor.constraint(equalTo: vw.centerXAnchor, constant: 35),
                bv.centerYAnchor.constraint(equalTo: vw.centerYAnchor),
            ])
        }
        _ = UILabel(autolayout: true).add(to: vw.contentView) { bv in
            bv.text = "+"
            NSLayoutConstraint.activate([
                bv.centerXAnchor.constraint(equalTo: vw.centerXAnchor),
                bv.bottomAnchor.constraint(equalTo: vw.centerYAnchor, constant: -30),
            ])
        }
        _ = UILabel(autolayout: true).add(to: vw.contentView) { bv in
            bv.text = "-"
            NSLayoutConstraint.activate([
                bv.centerXAnchor.constraint(equalTo: vw.centerXAnchor),
                bv.topAnchor.constraint(equalTo: vw.centerYAnchor, constant: 30),
            ])
        }

        NSLayoutConstraint.activate(vw.constraints(equalTo: backgroundView.contentView))
    }
    lazy var currentTimeLabel: UILabel = UILabel(autolayout: true).add(to: vibrancyView2.contentView) { lbl in
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    lazy var beginTimeLabel: UILabel = UILabel(autolayout: true).add(to: vibrancyView2.contentView) { lbl in
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: lbl.superview!.leadingAnchor, constant: UIScreen.main.traitCollection.horizontalSizeClass == .compact ? 10 : 30),
            lbl.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    lazy var endTimeLabel: UILabel = UILabel(autolayout: true).add(to: vibrancyView2.contentView) { lbl in
        NSLayoutConstraint.activate([
            lbl.trailingAnchor.constraint(equalTo: lbl.superview!.trailingAnchor, constant: UIScreen.main.traitCollection.horizontalSizeClass == .compact ? -10 : -30),
            lbl.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    lazy var backgroundView: UIVisualEffectView = UIVisualEffectView().add(to: owningView) { vw in
        vw.clipsToBounds = true
        vw.effect = UIBlurEffect(style: .dark)
    }
    lazy var playView: JoystickControl = JoystickControl().insert(to: owningView, above: backgroundView) { (pv) in
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.thumbTintColor = .clear
        pv.regionTintColor = .clear
        pv.setThumbImage(playImage(UIColor.black.withAlphaComponent(0.8)), for: .normal)
        pv.setThumbImage(.colored(by: UIColor.black.withAlphaComponent(0.2).cgColor), for: .touched)
        pv.setThumbImage(.colored(by: UIColor.black.withAlphaComponent(0.2).cgColor), for: [.touched, .highlighted])
        pv.setThumbImage(pauseImage(UIColor.black.withAlphaComponent(0.8)), for: .selected)
        pv.setThumbImage(.colored(by: UIColor.black.withAlphaComponent(0.2).cgColor), for: [.selected, .highlighted])
        pv.setThumbImage(.colored(by: UIColor.black.withAlphaComponent(0.2).cgColor), for: [.selected, .highlighted, .touched])
        pv.setThumbImage(.colored(by: UIColor.black.withAlphaComponent(0.2).cgColor), for: [.selected, .touched])
        NSLayoutConstraint.activate(pv.constraints(equalToCenterOf: backgroundView.contentView))
        NSLayoutConstraint.activate(pv.constraints(equalToSize: CGSize(square: 60)))
    }
    lazy var playProgressLayer: CAShapeLayer = CAShapeLayer().add(to: playView) { (layer) in
        layer.strokeColor = ApplicationState.contraTintColor.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 2 / UIScreen.main.scale
        layer.strokeEnd = 0
        if let sl = layer.superlayer {
            layer.frame = sl.bounds
            layer.path = CGPath(ellipseIn: sl.bounds, transform: nil)
        }
    }
    lazy var downloadProgressLayer: CAShapeLayer = CAShapeLayer().insert(to: playView, below: playProgressLayer) { (layer) in
        layer.strokeColor = ApplicationState.tintColor.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 2 / UIScreen.main.scale
        layer.strokeEnd = 0
        if let sl = layer.superlayer {
            layer.frame = sl.bounds
            layer.path = CGPath(ellipseIn: sl.bounds, transform: nil)
        }
    }

    var isTouchDown: Bool = false {
        didSet {
            layout()
            vibrancyView1.isHidden = isTouchDown
            vibrancyView2.isHidden = !isTouchDown
            backgroundView.contentView.layoutIfNeeded()
        }
    }

    override var owningView: UIView? {
        didSet {
            if let _ = owningView {
                vibrancyView1.isHidden = false
            }
        }
    }

    override func layout() {
        super.layout()
        let height = layoutFrame.height + 30
        backgroundView.frame = CGRect(
            center: layoutFrame.center,
            size: isTouchDown ? CGSize(width: layoutFrame.width, height: height) : CGSize(square: height)
        )
        backgroundView.layer.cornerRadius = height / 2
    }
}

final class ButtonsBar: UILayoutGuide {
    lazy var backgroundView: UIVisualEffectView = UIVisualEffectView(autolayout: true).add(to: owningView) { vw in
        vw.clipsToBounds = true
        vw.effect = UIBlurEffect(style: .dark)
        vw.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        NSLayoutConstraint.activate(vw.constraints(equalTo: self))
    }
    var images: [String] {
        if #available(iOS 13.0, *) {
            return ["plus", "heart.fill"]
        } else {
            return ["✚", "❤︎"]
        }
    }
    private lazy var buttons: [UIButton] = images.reduce(into: [UIButton]()) { (container, image) in
        let btn = UIButton(autolayout: true)
        backgroundView.contentView.addSubview(btn)
        btn.setBackgroundImage(.colored(by: UIColor.black.withAlphaComponent(0.5).cgColor), for: .normal)
        btn.setBackgroundImage(.colored(by: UIColor.black.withAlphaComponent(0.2).cgColor), for: .highlighted)
        if #available(iOS 13.0, *) {
            btn.setImage(UIImage(systemName: image), for: .normal)
            btn.setImage(UIImage(systemName: image)?.withTintColor(.red, renderingMode: .alwaysOriginal), for: .selected)
            btn.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(scale: .large), forImageIn: .normal)
        } else {
            btn.setTitle(image, for: .normal)
            btn.setTitleColor(.red, for: .selected)
            btn.titleLabel?.font = .systemFont(ofSize: 30, weight: .heavy)
        }
        btn.clipsToBounds = true
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8),
            btn.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        NSLayoutConstraint.activate(btn.constraints(equalToSize: CGSize(square: 50)))
        if let prev = container.last {
            NSLayoutConstraint.activate([btn.topAnchor.constraint(equalTo: prev.bottomAnchor, constant: 5)])
        } else {
            NSLayoutConstraint.activate([btn.topAnchor.constraint(equalTo: topAnchor, constant: 8)])
        }
        container.append(btn)
        if container.count == 2 {
            NSLayoutConstraint.activate([btn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)])
        }
    }
    var like: UIButton { buttons[1] }
    var add: UIButton { buttons[0] }

    override func layout() {
        super.layout()
        backgroundView.layer.cornerRadius = backgroundView.frame.width / 4
        buttons.forEach({ $0.layer.cornerRadius = $0.frame.width / 4 })
    }
}

final class ButtonsBar2: UILayoutGuide {
    lazy var backgroundView: UIVisualEffectView = UIVisualEffectView(autolayout: true).add(to: owningView) { vw in
        vw.clipsToBounds = true
        vw.layer.maskedCorners = axis == .horizontal ? [.layerMinXMinYCorner, .layerMaxXMinYCorner] : [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        vw.effect = UIBlurEffect(style: .dark)
        NSLayoutConstraint.activate(vw.constraints(equalTo: self))
    }
    var images: [String] {
        if #available(iOS 13.0, *) {
            return ["folder.fill", "text.quote", "repeat", "arrow.up.arrow.down", "shuffle"]
        } else {
            return ["🗂", "📖", "⇄", "⇅", "⤮"]
        }
    }
    lazy var buttons: [UIButton] = images.reduce(into: [UIButton]()) { (container, image) in
        let btn = UIButton(autolayout: true)
        backgroundView.contentView.addSubview(btn)
        btn.setBackgroundImage(.colored(by: UIColor.black.withAlphaComponent(0.5).cgColor), for: .normal)
        btn.setBackgroundImage(.colored(by: UIColor.black.withAlphaComponent(0.2).cgColor), for: .highlighted)
        if #available(iOS 13.0, *) {
            btn.setImage(UIImage(systemName: image), for: .normal)
            btn.setImage(UIImage(systemName: image)?.withTintColor(.red, renderingMode: .alwaysOriginal), for: .selected)
            btn.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(scale: .large), forImageIn: .normal)
        } else {
            btn.setTitle(image, for: .normal)
            btn.setTitleColor(.red, for: .selected)
            btn.titleLabel?.font = .systemFont(ofSize: 30, weight: .regular)
        }
        btn.clipsToBounds = true
        NSLayoutConstraint.activate([
            /// btn.dimension(for: axis.inverted).constraint(equalTo: dimension(for: axis.inverted), multiplier: 0.8),
            axis == .horizontal ?
                btn.topAnchor.constraint(equalTo: topAnchor, constant: 6) :
                btn.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        NSLayoutConstraint.activate(btn.constraints(equalToSize: CGSize(square: 50)))
        if let prev = container.last {
            NSLayoutConstraint.activate([
                axis == .horizontal ?
                    btn.leadingAnchor.constraint(equalTo: prev.trailingAnchor, constant: container.count == 2 ? 40 : 5) :
                    btn.topAnchor.constraint(equalTo: prev.bottomAnchor, constant: container.count == 2 ? 40 : 5)
            ])
        } else {
            NSLayoutConstraint.activate([
                axis == .horizontal ?
                    btn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8) :
                    btn.topAnchor.constraint(equalTo: topAnchor, constant: 8)
            ])
        }
        container.append(btn)
        if container.count == images.count {
            if #available(iOS 13.0, *) {} else { btn.titleEdgeInsets.bottom = 5 }
            NSLayoutConstraint.activate([
                axis == .horizontal ?
                    btn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8) :
                    btn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
            ])
        }
    }

    let axis: Axis
    init(axis: Axis) {
        self.axis = axis
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        backgroundView.layer.cornerRadius = backgroundView.frame.dimension(for: axis.inverted) / 4
        buttons.forEach({ $0.layer.cornerRadius = $0.frame.dimension(for: axis.inverted) / 4 })
    }
}

final class TitleLayout: UILayoutGuide {
    lazy var backgroundView: UIVisualEffectView = UIVisualEffectView(autolayout: true).add(to: owningView) { vw in
        vw.clipsToBounds = true
        vw.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        vw.effect = UIBlurEffect(style: .dark)
        NSLayoutConstraint.activate(vw.constraints(equalTo: self))
    }
    lazy var vibrancyView1: UIVisualEffectView = UIVisualEffectView(autolayout: true).add(to: backgroundView.contentView) { vw in
        if #available(iOS 13.0, *) {
            vw.effect = UIVibrancyEffect(blurEffect: backgroundView.effect as! UIBlurEffect, style: .label)
        }
        NSLayoutConstraint.activate(vw.constraints(equalTo: backgroundView.contentView))
    }
    lazy var titleLabel: UILabel = UILabel(autolayout: true).add(to: vibrancyView1.contentView) { lbl in
        lbl.numberOfLines = 0
        lbl.textColor = .white
        lbl.adjustsFontSizeToFitWidth = true
        NSLayoutConstraint.activate(lbl.constraints(equalTo: vibrancyView1.contentView, edgeInsets: UIEdgeInsets(horizontal: 20, vertical: 15)))
    }

    override func layout() {
        super.layout()
        backgroundView.layer.cornerRadius = backgroundView.frame.height / 4
    }
}

final class PlayerViewController: UIViewController {
    lazy var pageView: UIPageViewController = UIPageViewController().add(to: self) { pv in
        pv.view.translatesAutoresizingMaskIntoConstraints = false
        view.sendSubviewToBack(pv.view)
        NSLayoutConstraint.activate(pv.view.constraints(equalTo: view))
    }
    lazy var playbackLayout: PlaybackLayout = PlaybackLayout().add(to: view) { (pl) in
        NSLayoutConstraint.activate(pl.constraints(equalToWidthOf: view, multiplier: traitCollection.horizontalSizeClass == .compact ? 0.9 : 0.8, height: 80))
        NSLayoutConstraint.activate([
            pl.bottomAnchor.constraint(equalTo: buttonsBar2.topAnchor, constant: -40),
            pl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    lazy var buttonsBar: ButtonsBar = ButtonsBar().add(to: view) { bb in
        NSLayoutConstraint.activate([
            bb.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            bb.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    var buttonsBar2Height: NSLayoutConstraint?
    lazy var buttonsBar2: ButtonsBar2 = ButtonsBar2(axis: .horizontal).add(to: view) { bb in
        buttonsBar2Height = bb.heightAnchor.constraint(equalToConstant: view.safeAreaInsets.bottom + 63)
        NSLayoutConstraint.activate([
            buttonsBar2Height!,
            bb.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bb.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    lazy var titleLayout: TitleLayout = TitleLayout().add(to: view) { tl in
        NSLayoutConstraint.activate([
            tl.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            tl.bottomAnchor.constraint(lessThanOrEqualTo: buttonsBar.topAnchor, constant: -10),
            tl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tl.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ])
    }

    var timer: Timer?
    var startTouchDate: Date?
    var notificationObserver: NSObjectProtocol?
    var timeObserver: Any?
    lazy var bufferringProgress: Progress = Progress(totalUnitCount: 1)
    var currentProgress: Progress? {
        didSet {
            if var progress = currentProgress {
                if !queue.shouldPreloadTrackData {
                    let parent = Progress(totalUnitCount: 12)
                    parent.addChild(progress, withPendingUnitCount: 2)
                    bufferringProgress.completedUnitCount = 0
                    parent.addChild(bufferringProgress, withPendingUnitCount: 2)
                    currentProgress = parent
                    progress = parent
                }
                progressObserver = progress.observe(\.fractionCompleted) { [weak self] (p, change) in
                    DispatchQueue.main.async {
                        self?.playbackLayout.downloadProgressLayer.strokeEnd = CGFloat(p.fractionCompleted)
                    }
                }
            } else {
                progressObserver = nil
            }
            let currentTrack = queue.currentTrack
            let currentTrackID = currentTrack?.id
            buttonsBar.like.isSelected = ApplicationState.shared.likedQueue?.tracks.contains(where: { $0.id == currentTrackID }) == true
            playbackLayout.downloadProgressLayer.strokeEnd = 0
            playbackLayout.playProgressLayer.strokeEnd = 0
            if let track = currentTrack {
                let title = NSMutableAttributedString(string: track.title, attributes: [.font: UIFont.systemFont(ofSize: 30, weight: .semibold)])
                if let artists = track.artists {
                    title.append(
                        NSAttributedString(
                            string: "\n" + artists.map({ $0.name }).joined(separator: ", "),
                            attributes: [.font: UIFont.systemFont(ofSize: 20, weight: .light)]
                        )
                    )
                }
                titleLayout.titleLabel.attributedText = title
                track.durationMs.map({ $0 / 1000 }).map(TimeInterval.init).map(Date.init(timeIntervalSince1970:)).map(timeFormatter.string).map { time in
                    playbackLayout.endTimeLabel.text = time
                    playbackLayout.beginTimeLabel.text = "00:00"
                }

                ApplicationState.shared.nowPlayingItem.transaction { item in
                    item.title = track.title
                    item.albumTitle = track.albums?.map(\.title).joined(separator: ", ")
                    item.artist = track.artists?.map(\.name).joined(separator: ", ")
                    item.playbackDuration = track.durationMs.map({ TimeInterval($0 / 1000) })
                }
            }
        }
    }
    var progressObserver: KVObserver<Progress, Double>?
    var currentItem: AVPlayerItem? {
        set {
            player.currentItem.map(player.remove(_:))
            playbackLayout.playProgressLayer.strokeEnd = 0
            if let value = newValue {
                player.insert(value, after: nil)
                if let current = currentProgress, !queue.shouldPreloadTrackData, let trackDurationMs = queue.currentTrack?.durationMs {
                    let progress = Progress(totalUnitCount: 10)
                    let trackDuration = Double(trackDurationMs / 1000)
                    availableDurationObserver = value.observe(\.duration, options: [.initial, .new], changeHandler: { (item, change) in
                        progress.completedUnitCount = Int64((change.newValue!.seconds.onNan(0) / trackDuration) * Double(10))
                    })
                    current.addChild(progress, withPendingUnitCount: 8)
                }
            }
        }
        get { player.currentItem }
    }
    var availableDurationObserver: KVObserver<AVPlayerItem, CMTime>?
    var timeControlStatusObserver: KVObserver<AVQueuePlayer, AVPlayer.TimeControlStatus>?

    var videoController: UIViewController?

    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm:ss"
        return formatter
    }()
    let player: AVQueuePlayer = AVQueuePlayer()
    var queue: PlayerQueue {
        didSet {
            if oldValue.id != queue.id {
                buttonsBar2.buttons[2].isSelected = queue.settings.repeated
                buttonsBar2.buttons[3].isSelected = queue.settings.reversed
                buttonsBar2.buttons[4].isSelected = queue.settings.shuffled
                preparePlaying()
            }
        }
    }

    init(queue: PlayerQueue) {
        self.queue = queue
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(player, action: #selector(AVPlayer.playAction))
        commandCenter.pauseCommand.removeTarget(player, action: #selector(AVPlayer.pauseAction))
        commandCenter.togglePlayPauseCommand.removeTarget(player, action: #selector(AVPlayer.toggleAction))
        commandCenter.stopCommand.removeTarget(player, action: #selector(AVPlayer.pauseAction))
        commandCenter.nextTrackCommand.removeTarget(self, action: #selector(nextTrackAction))
        commandCenter.previousTrackCommand.removeTarget(self, action: #selector(prevTrackAction))

        notificationObserver.map(NotificationCenter.default.removeObserver)
        timeObserver.map(player.removeTimeObserver)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let videoBtn = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(showVideo))
        navigationItem.rightBarButtonItem = videoBtn

        let playView = playbackLayout.playView
        playView.addTarget(self, action: #selector(playViewTouchUpOutside(_:)), for: .touchUpOutside)
        playView.addTarget(self, action: #selector(playViewTouchUpInside(_:)), for: .touchUpInside)
        playView.addTarget(self, action: #selector(playViewTouchDown(_:)), for: .touchDown)

        buttonsBar.add.addTarget(self, action: #selector(addButtonTouchUpInside(_:)), for: .touchUpInside)
        buttonsBar.like.addTarget(self, action: #selector(likeButtonTouchUpInside(_:)), for: .touchUpInside)

        buttonsBar2.buttons[0].addTarget(self, action: #selector(showTracks), for: .touchUpInside)
        buttonsBar2.buttons[1].addTarget(self, action: #selector(showLyrics), for: .touchUpInside)
        buttonsBar2.buttons[2].addTarget(self, action: #selector(toggleRepeated(_:)), for: .touchUpInside)
        buttonsBar2.buttons[3].addTarget(self, action: #selector(toggleReversed(_:)), for: .touchUpInside)
        buttonsBar2.buttons[4].addTarget(self, action: #selector(toggleShuffled(_:)), for: .touchUpInside)

        notificationObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) { [unowned self] _ in
            didEndPlaying()
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: nil, using: { [unowned self] (time) in
            if let item = player.currentItem, item.duration.value > 0 {
                playbackLayout.playProgressLayer.strokeEnd = CGFloat(time.seconds / item.duration.seconds)
                playbackLayout.currentTimeLabel.text = timeFormatter.string(from: Date(timeIntervalSince1970: time.seconds))
            }
        })

        preparePlaying()

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget(player, action: #selector(AVPlayer.playAction))
        commandCenter.pauseCommand.addTarget(player, action: #selector(AVPlayer.pauseAction))
        commandCenter.togglePlayPauseCommand.addTarget(player, action: #selector(AVPlayer.toggleAction))
        commandCenter.stopCommand.addTarget(player, action: #selector(AVPlayer.pauseAction))
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(nextTrackAction))
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(prevTrackAction))

        timeControlStatusObserver = player.observe(\.timeControlStatus) { [unowned self] (p, c) in
            if !bufferringProgress.isFinished {
                bufferringProgress.completedUnitCount = p.timeControlStatus == .waitingToPlayAtSpecifiedRate || p.currentItem?.isPlaybackLikelyToKeepUp == false ? 0 : 1
            }
            playbackLayout.playView.isSelected = p.timeControlStatus != .paused
            ApplicationState.shared.nowPlayingItem.transaction { (item) in
                item.rate = p.timeControlStatus == .playing ? p.rate : 0
                item.elapsedPlaybackTime = p.currentItem?.currentTime().seconds
            }
            #if targetEnvironment(macCatalyst)
            MPNowPlayingInfoCenter.default().playbackState = p.timeControlStatus == .playing ? .playing : .paused
            #endif
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if view.window == nil {
            queue.willPlay()
            if isPresented || isBeingPresented {
                let btn = UIButton()
                btn.setTitle("Minimize", for: .normal)
                btn.addTarget(self, action: #selector(minimize), for: .touchUpInside)
                navigationItem.titleView = btn
            } else {
                navigationItem.leftBarButtonItem = UIBarButtonItem(title: "⬅︎", style: .done, target: self, action: #selector(backButtonAction))
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.updateLayoutGuides()
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        buttonsBar2Height?.constant = view.safeAreaInsets.bottom + 63
    }

    @objc private func minimize() {
        let main = mainViewController
        dismiss(animated: true) {
            main?.playerViewController = self
        }
    }

    @objc private func backButtonAction() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func addButtonTouchUpInside(_ btn: UIButton) {
        guard let track = queue.currentTrack else { return print("no track") }
        guard let albumId = track.albums?.first.map({ String($0.id) }) else { return print("no album") }

        btn.isEnabled = false
        let userID = ApplicationState.shared.username!
        let client = queue.client
        client.playlists(ofUserWith: userID) { [weak self] (result) in
            DispatchQueue.main.async {
                guard let `self` = self else { return }
                switch result {
                case .failure(let error):
                    print(error)
                    btn.isEnabled = true
                case .success(let user):
                    let navigationController = UINavigationController()
                    let pickerViewController = ItemListViewController<PlaylistItem>(user.map(PlaylistItem.init)) { (select) in
                        btn.isEnabled = true
                        guard let (_, item) = select else { return }

                        let queue = UserPlaylistQueue(ofUser: ApplicationState.shared.username!, playlist: item.playlist, client: ApplicationState.shared.client, cacheFolder: ApplicationState.shared.cacheFolder)
                        let tracksViewController = TracksViewController(queue: queue, movable: (0, track)) { (q) in
                            guard let index = q.currentTrackIndex else { return }
                            let change = PlaylistChange(kind: item.playlist.kind, revision: item.playlist.revision, diff: [.insert([.init(id: track.id, albumId: albumId)], at: index)])
                            client.playlist(change: change, userID: userID) { (result2) in
                                switch result2 {
                                case .failure(let error):
                                    print(error)
                                case .success(let playlist):
                                    print(playlist)
                                }
                            }
                        }
                        tracksViewController.style = .system
                        navigationController.pushViewController(tracksViewController, animated: true)
                    }
                    pickerViewController.shouldCloseOnSelect = false
                    pickerViewController.navigationItem.rightBarButtonItem = .cancel(pickerViewController, action: #selector(pickerViewController.dismissAnimated))
                    navigationController.viewControllers = [pickerViewController]
                    self.present(navigationController, animated: true, completion: nil)
                }
            }
        }
    }

    @objc private func likeButtonTouchUpInside(_ btn: UIButton) {
        guard let track = queue.currentTrack else { return }
        btn.isEnabled = false
        let userID = ApplicationState.shared.username!
        queue.client.like(action: btn.isSelected ? .remove : .add, for: .track, with: [track.id], userID: userID) { (result) in
            DispatchQueue.main.async {
                switch result {
                case .failure(let err): print(err)
                case .success:
                    btn.isSelected.toggle()
                }
                btn.isEnabled = true
            }
        }
    }

    @objc private func toggleRepeated(_ btn: UIButton) {
        queue.settings.repeated.toggle()
        btn.isSelected = queue.settings.repeated
    }
    @objc private func toggleReversed(_ btn: UIButton) {
        queue.settings.reversed.toggle()
        btn.isSelected = queue.settings.reversed
    }
    @objc private func toggleShuffled(_ btn: UIButton) {
        queue.settings.shuffled.toggle()
        btn.isSelected = queue.settings.shuffled
    }

    @objc private func showTracks() {
        let previousIndex = queue.currentTrackIndex
        let tracksViewController = TracksViewController(queue: queue) { [unowned self] (q) in
            guard q.currentTrackIndex != previousIndex else { return }
            let offset = q.currentTrackIndex.map({ i in previousIndex.map { $0 - i } ?? i })!
            let vc = UIViewController()
            vc.view = trackView(for: q.currentTrack!)
            pageView.setViewControllers([vc], direction: offset > 0 ? .forward : .reverse, animated: true, completion: nil)
            currentProgress = queue.prepareCurrentTrack { [weak self] (result) in
                switch result {
                case .failure(let error): print(error)
                case .success(let url):
                    DispatchQueue.main.async { [weak self] in
                        guard let `self` = self else { return }
                        if let prev = previousIndex {
                            self.queue.didPlay(trackAt: prev, played: player.currentTime().seconds.onNan(
                                player.currentItem.map({ $0.duration.seconds }) ??
                                    queue.tracks[prev].durationMs.map({ TimeInterval($0 / 1000) }) ?? 0
                            ))
                        }
                        self.play(fileUrl: url)
                    }
                }
            }
        }
        tracksViewController.navigationItem.rightBarButtonItem = .cancel(self, action: #selector(dismissPresented))
        let presentedController = tracksViewController.navigated()
        presentedController.modalPresentationStyle = .overFullScreen
        present(presentedController, animated: true, completion: nil)
    }

    @objc private func showLyrics() {
        guard let track = queue.currentTrack, track.lyricsAvailable else { return }
        let vc = LyricsViewController()
        vc.navigationItem.rightBarButtonItem = .cancel(self, action: #selector(dismissPresented))
        queue.client.supplement(forTrackWith: track.id) { (result) in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error): vc.text = String(describing: error)
                case .success(let supplement):
                    vc.text = supplement.lyrics?.fullLyrics
                }
            }
        }
        let presentedController = vc.navigated()
        presentedController.modalPresentationStyle = .overFullScreen
        present(presentedController, animated: true, completion: nil)
    }

    @objc private func showVideo(_ btn: UIBarButtonItem) {
        guard let track = queue.currentTrack else { return }
        guard videoController == nil else {
            btn.tintColor = view.tintColor
            UIView.animate(withDuration: 0.3, animations: {
                self.videoController!.view.frame.origin.y = self.view.frame.height
            }) { _ in
                self.remove(child: self.videoController!)
                self.videoController = nil
            }
            return
        }
        btn.tintColor = .red
        let vc = UIViewController()
        let videoView = WKWebView(autolayout: true)
        videoView.configuration.allowsInlineMediaPlayback = true
        vc.view = videoView
        add(child: vc)
        view.insertSubview(videoView, aboveSubview: pageView.view)
        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        queue.client.supplement(forTrackWith: track.id) { (result) in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error): videoView.loadHTMLString(String(describing: error), baseURL: nil)
                case .success(let supplement):
                    guard let youtube = supplement.videos?.first(where: { $0.provider == "youtube" }), let videoId = youtube.providerVideoId else {
                        guard let yandex = supplement.videos?.first(where: { $0.provider == "yandex" }), let videoId = yandex.providerVideoId else {
                            if let undefined = supplement.videos?.first {
                                if let embedUrl = undefined.embedUrl {
                                    videoView.load(URLRequest(url: URL(string: embedUrl)!))
                                } else if let embed = undefined.embed {
                                    let style = "<style>body {margin:0} iframe {display:block;border:none;height:100vh;width:100vw;}</style>"
                                    videoView.loadHTMLString(style + embed, baseURL: undefined.url.flatMap(URL.init(string:)))
                                }
                            }
                            return
                        }
                        videoView.load(URLRequest(url: URL(string: yandex.embedUrl ?? "https://frontend.vh.yandex.ru/player/\(videoId)")!))
                        return
                    }
                    videoView.load(URLRequest(url: URL(string: youtube.embedUrl ?? "https://www.youtube.com/embed/\(videoId)?autoplay=1&mute=1")!))
                }
            }
        }

        vc.view.frame.origin.y = view.frame.height
        UIView.animate(withDuration: 0.3) {
            vc.view.frame.origin.y = 0
        }
        videoController = vc
    }

    @objc private func dismissPresented() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func nextTrackAction() -> MPRemoteCommandHandlerStatus {
        guard queue.canAdvance(toTrackBy: 1) else { return .commandFailed }
        advance(by: 1)
        return .success
    }
    @objc private func prevTrackAction() -> MPRemoteCommandHandlerStatus {
        guard queue.canAdvance(toTrackBy: -1) else { return .commandFailed }
        advance(by: -1)
        return .success
    }

    private func preparePlaying(_ completion: (() -> Void)? = nil) {
        queue.prepare { [weak self] (result) in
            guard let `self` = self else { return }
            switch result {
            case .failure(let err): print(err)
            case .success(let tracks):
                DispatchQueue.main.async {
                    guard let vc = tracks.first.map(self.trackView).map(UIViewController.init(view:)) else { return }
                    self.pageView.setViewControllers([vc], direction: .forward, animated: self.view.window != nil, completion: nil)
                    self.queue.currentTrackIndex = 0
                    self.currentProgress = self.queue.prepareCurrentTrack { [weak self] (result) in
                        switch result {
                        case .failure(let error): print(error)
                        case .success(let url):
                            DispatchQueue.main.async { [weak self] in
                                guard let `self` = self else { return }
                                self.currentItem = AVPlayerItem(asset: AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/mp3"]))
                                self.queue.willPlay(trackAt: 0)
                                completion?()
                            }
                        }
                    }
                }
            }
        }
    }

    private func didEndPlaying() {
        advance(by: 1)
    }

    private func advance(by trackIndexOffset: Int, pageViewController: UIViewController? = nil) {
        guard queue.canAdvance(toTrackBy: trackIndexOffset) else { return }
        let didPlay: (index: Int, played: TimeInterval)? = queue.currentTrackIndex.map { prev in
            (prev, player.currentTime().seconds.onNan(
                player.currentItem.map({ $0.duration.seconds }) ??
                    queue.tracks[prev].durationMs.map({ TimeInterval($0 / 1000) }) ?? 0
            ))
        }
        let vc = pageViewController ?? UIViewController()
        pageView.setViewControllers([vc], direction: trackIndexOffset > 0 ? .forward : .reverse, animated: true, completion: nil)
        queue.advance(toTrackBy: trackIndexOffset) { (result) in
            switch result {
            case .failure(let error): print(error)
            case .success(let track):
                DispatchQueue.main.async {
                    vc.view = self.trackView(for: track)
                    self.currentProgress = self.queue.prepareCurrentTrack { (urlResult) in
                        switch urlResult {
                        case .failure(let error): print(error)
                        case .success(let url):
                            DispatchQueue.main.async {
                                if let event = didPlay {
                                    self.queue.didPlay(trackAt: event.index, played: event.played)
                                }
                                self.play(fileUrl: url)
                            }
                        }
                    }
                }
            }
        }
    }

    private func trackView(for track: Track) -> UIView {
        let view = TrackControllerView()
        #if targetEnvironment(macCatalyst)
        let size = 1000
        #else
        let size = 400
        #endif
        if let url = track.coverUrl(forImageSize: size).flatMap(URL.init(string:)) {
            URLSession.shared.dataTask(with: url) { (data, response, err) in
                guard let img = data.flatMap(UIImage.init) else { return print("No image", data ?? Data(), err ?? NSError()) }

                DispatchQueue.main.async {
                    view.imageView.image = img
                    ApplicationState.shared.nowPlayingItem.transaction { (item) in
                        item.artWork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                    }
                }
            }.resume()
        }
        return view
    }

    private func play(fileUrl: URL) {
        let asset = AVURLAsset(url: fileUrl, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/mp3"])
        currentItem = AVPlayerItem(asset: asset)
        if let index = queue.currentTrackIndex {
            queue.willPlay(trackAt: index)
        }
        player.play()
        playbackLayout.playView.isSelected = true
    }

    @objc private func playViewTouchUpInside(_ control: ManipulatorView) {
        timer?.invalidate()
        timer = nil
        control.transform = .identity
        defer {
            startTouchDate = nil
            UIView.animate(withDuration: 0.3) { self.playbackLayout.isTouchDown = false }
        }
        if let pos = direction(control.position) {
            guard startTouchDate.map({ $0.timeIntervalSinceNow > -0.3 }) == true else {
                return ApplicationState.shared.nowPlayingItem.transaction { (item) in
                    item.elapsedPlaybackTime = currentItem?.currentTime().seconds
                }
            }
            if pos == .left || pos == .right {
                makeAction(with: pos == .left ? .prevTrack : .nextTrack)
            }
        } else if (-0.5 ... 0.5).contains(control.position.x), (-0.5 ... 0.5).contains(control.position.y) {
            if player.timeControlStatus != .paused {
                player.pause()
            } else {
                player.play()
            }
        }
    }
    @objc private func playViewTouchUpOutside(_ control: ManipulatorView) {
        timer?.invalidate()
        timer = nil
        control.transform = .identity
        defer {
            startTouchDate = nil
            UIView.animate(withDuration: 0.3) { self.playbackLayout.isTouchDown = false }
        }
        guard startTouchDate.map({ $0.timeIntervalSinceNow > -0.3 }) == true else {
            return ApplicationState.shared.nowPlayingItem.transaction { (item) in
                item.elapsedPlaybackTime = currentItem?.currentTime().seconds
            }
        }
        if let pos = direction(control.position), pos == .left || pos == .right {
            makeAction(with: pos == .left ? .prevTrack : .nextTrack)
        }
    }
    @objc private func playViewTouchDown(_ control: ManipulatorView) {
        startTouchDate = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [unowned self] (timer) in
            let timeIntervalSinceNow = startTouchDate!.timeIntervalSinceNow
            let isTouchDown = (timeIntervalSinceNow < -0.3) == true
            control.transform = isTouchDown ? .identity : CGAffineTransform(scaleX: 1 - CGFloat(timeIntervalSinceNow), y: 1 - CGFloat(timeIntervalSinceNow))
            if playbackLayout.isTouchDown != isTouchDown {
                UIView.animate(withDuration: 0.3) { self.playbackLayout.isTouchDown = isTouchDown }
            }
            guard let position = direction(control.position) else { return }
            switch position {
            case .up, .down:
                makeAction(with: position == .up ? .volumeUp : .volumeDown)
            case .left, .right:
                if isTouchDown {
                    makeAction(with: position == .left ? .moveBack : .moveForward)
                }
            @unknown default: fatalError()
            }
        })
    }
    private func makeAction(with direction: ManipulatorAction) {
        switch direction {
        case .volumeUp:
            player.volume = min(player.volume + 0.01 * Float(playbackLayout.playView.position.y) / 2, 1)
            playbackLayout.currentTimeLabel.text = String(format: "%.1f", arguments: [player.volume])
        case .volumeDown:
            player.volume = max(player.volume - 0.01 * -Float(playbackLayout.playView.position.y) / 2, 0)
            playbackLayout.currentTimeLabel.text = String(format: "%.1f", arguments: [player.volume])
        case .prevTrack:
            advance(by: -1)
        case .nextTrack:
            advance(by: 1)
        case .moveBack:
            let time = player.currentTime()
            let offset = player.timeControlStatus == .playing ? 2 : 0.5
            player.seek(to: CMTime(seconds: time.seconds - offset, preferredTimescale: time.timescale), toleranceBefore: .zero, toleranceAfter: .zero)
        case .moveForward:
            let time = player.currentTime()
            let offset = player.timeControlStatus == .playing ? 2 : 0.5
            player.seek(to: CMTime(seconds: time.seconds + offset, preferredTimescale: time.timescale), toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
    enum ManipulatorAction {
        case volumeUp, volumeDown
        case prevTrack, nextTrack
        case moveBack, moveForward
    }
    typealias ManipulatorPosition = UITextLayoutDirection
    private func direction(_ position: CGPoint) -> ManipulatorPosition? {
        switch (position.x, position.y) {
        case (-0.5 ... 0.5, 0.5 ... 1.0): return .up
        case (-0.5 ... 0.5, -1.0 ... -0.5): return .down
        case (0.5 ... 1, -0.5 ... 0.5): return .right
        case (-1.0 ... -0.5, -0.5 ... 0.5): return .left
        default: return nil
        }
    }
    private struct PlaylistItem: ListItem, Equatable {
        let playlist: YandexMusic.UserPlaylist
        var label: String { playlist.title }

        static func == (lhs: PlaylistItem, rhs: PlaylistItem) -> Bool {
            lhs.playlist.uid == rhs.playlist.uid
        }
    }
    private struct TrackItem: ListItem, Equatable {
        let track: YandexMusic.Track
        var label: String { (track.artists.flatMap({ $0.first?.name }).map({ $0 + " - " }) ?? "") + track.title }

        static func == (lhs: TrackItem, rhs: TrackItem) -> Bool {
            lhs.track.id == rhs.track.id
        }
    }
}
extension PlayerViewController {
    func miniView() -> (control: UIControl, image: UIImage?) {
        let btn = UIButton()
        if let track = queue.currentTrack {
            let title = NSMutableAttributedString(string: track.title, attributes: [.font: UIFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: UIColor.white])
//            if let artists = track.artists {
//                title.append(
//                    NSAttributedString(
//                        string: "\n" + artists.map({ $0.name }).joined(separator: ", "),
//                        attributes: [.font: UIFont.systemFont(ofSize: 20, weight: .light), .foregroundColor: UIColor.white]
//                    )
//                )
//            }
            btn.setAttributedTitle(title, for: .normal)
        } else {
            btn.setTitle("No active track", for: .normal)
        }
        btn.titleLabel?.textAlignment = .center
        btn.layer.cornerRadius = 10
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        return (btn, (pageView.viewControllers?.first?.view as? TrackControllerView)?.imageView.image)
    }
}
