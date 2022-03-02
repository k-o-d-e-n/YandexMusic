//
//  ViewController.swift
//  MusicYa
//
//  Created by Denis Koryttsev on 19.10.2020.
//

import UIKit
import AVFoundation

extension UIViewController {
    var mainViewController: ViewController? {
        var parent = self.parent
        while let p = parent {
            if let main = p as? ViewController {
                return main
            }
            if let newp = p.parent {
                parent = newp
            } else {
                parent = p.presentingViewController
            }
        }

        return nil
    }
}

class ViewController: UINavigationController {
    let queuesViewController = QueuesViewController(client: ApplicationState.shared.client, cacheFolder: ApplicationState.shared.cacheFolder)
    var playerViewController: PlayerViewController? {
        didSet {
            if let vc = playerViewController {
                let (button, image) = vc.miniView()
                button.addTarget(self, action: #selector(openPlayer), for: .touchUpInside)
                toolbar.setBackgroundImage(image, forToolbarPosition: .any, barMetrics: .default)
                setToolbarHidden(false, animated: true)
                queuesViewController.setToolbarItems([UIBarButtonItem(customView: button)], animated: true)
            } else {
                setToolbarHidden(true, animated: true)
                queuesViewController.setToolbarItems(nil, animated: false)
                toolbar.setBackgroundImage(nil, forToolbarPosition: .any, barMetrics: .default)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewControllers = [queuesViewController]
        toolbar.isTranslucent = false

        try! AVAudioSession.sharedInstance().setCategory(.playback)
        try! AVAudioSession.sharedInstance().setActive(true, options: [])

        /// use `duration` property observing in `AVPlayerItem` to detect loading progress
//        let files = try! FileManager.default.contentsOfDirectory(atPath: tracksFolder.relativePath)
//        if let fileUrl = files.first.map({ tracksFolder.appendingPathComponent($0, isDirectory: true) }) {
//            var components = URLComponents(string: "https://file-examples-com.github.io/uploads/2017/11/file_example_MP3_2MG.mp3")!
//            components.scheme = "custom"
//            components.path = fileUrl.relativePath + ".mp3"
//            let asset = AVURLAsset(url: components.url!)
//            asset.resourceLoader.setDelegate(self, queue: .main)
//            player.insert(AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: nil), after: nil)
//        player = AVPlayer(playerItem: AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: nil))
//        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let auth = ApplicationState.shared.auth
        if auth.token == nil {
            auth.getAccessToken({ print($0) })
        }
    }

    @objc private func openPlayer() {
        guard let vc = playerViewController else { return }

        let container = UINavigationController(rootViewController: vc)
        container.modalPresentationStyle = .fullScreen
        present(container, animated: true) { [unowned self] in
            playerViewController = nil
        }
    }
}
extension ViewController: AVAssetResourceLoaderDelegate {
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        /*let fileUrl = (player.currentItem!.asset as! AVURLAsset).url
        guard let handle = FileHandle(forReadingAtPath: fileUrl.path.replacingOccurrences(of: ".mp3", with: "")) else { fatalError() }

        loadingRequest.contentInformationRequest?.isByteRangeAccessSupported = true
        loadingRequest.contentInformationRequest?.contentType = "audio/mp3"
        loadingRequest.contentInformationRequest?.contentLength = 1 * .megabyte
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(1)) {
            let data = handle.readData(ofLength: 1 * .megabyte)
            loadingRequest.dataRequest?.respond(with: data)
            loadingRequest.response = URLResponse(url: fileUrl, mimeType: "audio/mp3", expectedContentLength: 1 * .megabyte, textEncodingName: nil)
            loadingRequest.finishLoading()
        }*/

        var components = URLComponents(url: loadingRequest.request.url!, resolvingAgainstBaseURL: false)!
        components.scheme = "https"
        URLSession.shared.dataTask(with: components.url!) { (data, response, error) in
            guard let d = data else {
                return loadingRequest.finishLoading(with: error)
            }
            loadingRequest.response = URLResponse(url: components.url!, mimeType: "audio/mp3", expectedContentLength: d.count, textEncodingName: nil)
            loadingRequest.dataRequest?.respond(with: d)
            loadingRequest.finishLoading()
        }.resume()

        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        print("cancel", loadingRequest)
    }
}
