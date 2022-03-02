//
//  Application.swift
//  MusicYa
//
//  Created by Denis Koryttsev on 23.12.2020.
//

import UIKit
import YandexAuth
import YandexMusic
import MediaPlayer

final class Auth: AccessTokenProvider {
    let client: YandexAuth = YandexAuth(clientID: "your_client_id", secret: "your_secret")

    init() {
        self.token = try! UserDefaults.standard.data(forKey: "access").map(JSONDecoder().decode)
    }

    var token: YandexAuth.AccessToken?
    var currentToken: String? { token?.value }

    func getAccessToken(_ completion: @escaping (Result<String, Error>) -> Void) {
        guard token == nil else { return completion(.success(token!.value)) }

        let alert = UIAlertController(title: "Auth", message: "", preferredStyle: .alert)
        var loginTF, passwordTF: UITextField!
        alert.addTextField { (tf) in
            loginTF = tf
        }
        alert.addTextField { (tf) in
            passwordTF = tf
            tf.isSecureTextEntry = true
        }

        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            self.client.auth(with: loginTF.text!, password: passwordTF.text!) { (res) in
                switch res {
                case .success(let t):
                    UserDefaults.standard.set(try! JSONEncoder().encode(t), forKey: "access")
                    self.token = t
                case .failure(let err):
                    print(err)
                }
            }
        }))

        UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
    }
}

final class ApplicationState {
    let auth: Auth
    let client: YandexMusic.Client
    let cacheFolder: URL
    private var _likedQueue: LikedTracksQueue?
    var likedQueue: LikedTracksQueue? {
        guard let q = _likedQueue else {
            guard let userId = username else { return nil }
            let queue = LikedTracksQueue(ofUser: userId, client: client, cacheFolder: cacheFolder)
            _likedQueue = queue
            return queue
        }
        return q
    }

    var username: String? {
        auth.token?.username
    }

    let nowPlayingItem: NowPlayingItem = NowPlayingItem()

    init(auth: Auth, client: YandexMusic.Client, cache cacheFolder: URL) {
        self.auth = auth
        self.client = client
        self.cacheFolder = cacheFolder
    }
}
extension ApplicationState {
    private static var _shared: ApplicationState!
    static var shared: ApplicationState { _shared }
    static func initialize(with auth: Auth, client: YandexMusic.Client, cache cacheFolder: URL) {
        _shared = ApplicationState(auth: auth, client: client, cache: cacheFolder)
    }

    static var tintColor: UIColor { .white }
    static var contraTintColor: UIColor { .red }
}

final class NowPlayingItem {
    @Property(key: MPMediaItemPropertyTitle) var title: String?
    @Property(key: MPMediaItemPropertyArtist) var artist: String?
    @Property(key: MPMediaItemPropertyAlbumArtist) var albumArtist: String?
    @Property(key: MPMediaItemPropertyAlbumTitle) var albumTitle: String?
    @Property(key: MPMediaItemPropertyArtwork) var artWork: MPMediaItemArtwork?
    @Property(key: MPMediaItemPropertyPlaybackDuration) var playbackDuration: TimeInterval?

    @Property(key: MPNowPlayingInfoPropertyElapsedPlaybackTime) var elapsedPlaybackTime: TimeInterval?
    @Property(key: MPNowPlayingInfoPropertyDefaultPlaybackRate) var defaultRate: Float?
    @Property(key: MPNowPlayingInfoPropertyPlaybackRate) var rate: Float?

    init() {
        if MPNowPlayingInfoCenter.default().nowPlayingInfo == nil {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
        }
    }

    @propertyWrapper
    struct Property<Value> {
        let key: String
        var wrappedValue: Value? {
            set {
                if NowPlayingItem.inTransaction {
                    NowPlayingItem.currentPlayingInfo[key] = newValue
                } else {
                    MPNowPlayingInfoCenter.default().nowPlayingInfo?[key] = newValue
                }
            }
            get { MPNowPlayingInfoCenter.default().nowPlayingInfo?[key] as? Value }
        }
    }

    func transaction(_ closure: (NowPlayingItem) -> Void) {
        NowPlayingItem.inTransaction = true
        closure(self)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = NowPlayingItem.currentPlayingInfo
        NowPlayingItem.inTransaction = false
    }

    private static var inTransaction: Bool = false
    private static var currentPlayingInfo: [String: Any] = [:]
}

func navigationButtonImage(_ background: UIColor, height: CGFloat) -> UIImage {
    let rect = CGRect(origin: .zero, size: CGSize(width: height + 1, height: height))
    UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
    let context = UIGraphicsGetCurrentContext()
    context?.setFillColor(background.cgColor)
    context?.addPath(CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil))
    context?.fillPath()
    let returnedImage = UIGraphicsGetImageFromCurrentImageContext()?
        .resizableImage(withCapInsets: UIEdgeInsets(horizontal: height / 2, vertical: 0), resizingMode: .stretch)
    UIGraphicsEndImageContext()
    return returnedImage!
}
func playImage(_ background: UIColor?) -> UIImage {
    let rect = CGRect(origin: .zero, size: CGSize(square: 50))
    UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
    let context = UIGraphicsGetCurrentContext()
    if let b = background {
        context?.setFillColor(b.cgColor)
        context?.fill(rect)
    }
    context?.setFillColor(UIColor.white.cgColor)
    context?.move(to: CGPoint(x: 18, y: 15))
    context?.addLine(to: CGPoint(x: 37, y: 25))
    context?.addLine(to: CGPoint(x: 18, y: 35))
    context?.fillPath()
    let returnedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return returnedImage!
}
func pauseImage(_ background: UIColor?) -> UIImage {
    let rect = CGRect(origin: .zero, size: CGSize(square: 50))
    UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
    let context = UIGraphicsGetCurrentContext()
    if let b = background {
        context?.setFillColor(b.cgColor)
        context?.fill(rect)
    }
    context?.setLineWidth(4)
    context?.setStrokeColor(UIColor.white.cgColor)
    context?.move(to: CGPoint(x: 20, y: 15))
    context?.addLine(to: CGPoint(x: 20, y: 35))
    context?.move(to: CGPoint(x: 30, y: 15))
    context?.addLine(to: CGPoint(x: 30, y: 35))
    context?.strokePath()
    let returnedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return returnedImage!
}

final class TrackControllerView: UIView {
    lazy var imageView: UIImageView = UIImageView(autolayout: true).add(to: self) { imgView in
        imgView.contentMode = .scaleAspectFill
        imgView.clipsToBounds = true
        let imgInset: CGFloat = 0
        NSLayoutConstraint.activate([
            imgView.topAnchor.constraint(equalTo: topAnchor, constant: imgInset),
            imgView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -imgInset),
            imgView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: imgInset),
            imgView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -imgInset),
        ])
    }
}

final class LyricsViewController: UIViewController, UITextViewDelegate {
    var contentView: UIView { (view as! UIVisualEffectView).contentView }
    lazy var textView: UITextView = UITextView(autolayout: true).add(to: contentView) { tv in
        tv.backgroundColor = .clear
        tv.textColor = .black
        tv.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        tv.contentInset = UIEdgeInsets(horizontal: 16, vertical: 20)
        tv.keyboardDismissMode = .interactive
        tv.delegate = self
        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: contentView.topAnchor),
            tv.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            tv.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    override var navigationBarColor: UIColor? { .white }

    var text: String? {
        didSet {
            if isViewLoaded {
                textView.text = text
            }
        }
    }

    override func loadView() {
        self.view = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.text = text
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        defaultScrollViewDidScroll(scrollView)
    }
}
