//
//  QueuesViewController.swift
//  MusicYa
//
//  Created by Denis Koryttsev on 27.11.2020.
//

import UIKit
import YandexMusic

final class QueuesViewController: UITableViewController {
    var queues: Queues = Queues()

    let client: YandexMusic.Client
    let cacheFolder: URL
    init(client: YandexMusic.Client, cacheFolder: URL) {
        self.client = client
        self.cacheFolder = cacheFolder
        super.init(nibName: nil, bundle: nil)
        self.title = "Queues"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        client.stationsDashboard { [weak self] (result) in
            guard let `self` = self else { return }
            switch result {
            case .failure(let error): print(error)
            case .success(let dashboard):
                DispatchQueue.main.async {
                    self.queues.radio = dashboard.stations.map({ $0.station })
                    self.tableView.performBatchUpdates {
                        self.tableView.reloadSections([Queue.radio.rawValue], with: .automatic)
                    }
                }
            }
        }
        client.feed { [weak self] (result) in
            guard let `self` = self else { return }
            switch result {
            case .failure(let error): print(error)
            case .success(let feed):
                DispatchQueue.main.async {
                    self.queues.feed = feed.generatedPlaylists.map({ $0.data })
                    self.tableView.performBatchUpdates {
                        self.tableView.reloadSections([Queue.feedPlaylist.rawValue], with: .automatic)
                    }
                }
            }
        }
        guard let username = ApplicationState.shared.username else { return }
        client.playlists(ofUserWith: username) { [weak self] (result) in
            guard let `self` = self else { return }
            switch result {
            case .failure(let error): print(error)
            case .success(let user):
                DispatchQueue.main.async {
                    self.queues.user = user
                    self.tableView.performBatchUpdates {
                        self.tableView.reloadSections([Queue.userPlaylist.rawValue], with: .automatic)
                    }
                }
            }
        }
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        defaultScrollViewDidScroll(scrollView)
    }

    enum Queue: Int {
        case downloaded
        case liked
        case userPlaylist
        case feedPlaylist
        case radio
    }
    struct Queues {
        var user: [UserPlaylist] = []
        var feed: [FeedPlaylist] = []
        var radio: [RadioStation] = []
    }
}
extension QueuesViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Queue(rawValue: section)! {
        case .liked, .downloaded: return 1
        case .userPlaylist: return queues.user.count
        case .feedPlaylist: return queues.feed.count
        case .radio: return queues.radio.count
        }
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Queue(rawValue: section)! {
        case .downloaded: return "Downloaded"
        case .liked: return "Liked"
        case .userPlaylist: return "Playlists"
        case .feedPlaylist: return "Feed"
        case .radio: return "Radio"
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        switch Queue(rawValue: indexPath.section)! {
        case .downloaded:
            cell.textLabel?.text = "Downloaded tracks"
        case .liked:
            cell.textLabel?.text = "Liked tracks"
        case .userPlaylist:
            let item = queues.user[indexPath.row]
            cell.textLabel?.text = item.title
            cell.detailTextLabel?.text = "\(item.trackCount)"
        case .feedPlaylist:
            let item = queues.feed[indexPath.row]
            cell.textLabel?.text = item.title
            cell.detailTextLabel?.text = "\(item.trackCount)"
        case .radio:
            let item = queues.radio[indexPath.row]
            cell.textLabel?.text = item.name
        }

        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let queue: PlayerQueue?
        switch Queue(rawValue: indexPath.section)! {
        case .downloaded: queue = DownloadedTracksQueue(client: client, cacheFolder: cacheFolder)
        case .liked: queue = LikedTracksQueue(ofUser: ApplicationState.shared.username!, client: client, cacheFolder: cacheFolder)
        case .userPlaylist:
            queue = UserPlaylistQueue(ofUser: ApplicationState.shared.username!, playlist: queues.user[indexPath.row], client: client, cacheFolder: cacheFolder)
        case .feedPlaylist:
            queue = FeedPlaylistQueue(playlist: queues.feed[indexPath.row], client: client, cacheFolder: cacheFolder)
        case .radio:
            queue = RadioQueue(station: queues.radio[indexPath.row], client: client, cacheFolder: cacheFolder)
        }
        guard let q = queue else { return }
        let playerViewController = mainViewController?.playerViewController.map({ $0.queue = q; return $0 }) ?? PlayerViewController(queue: q)
        let containerViewController = UINavigationController(rootViewController: playerViewController)
        containerViewController.modalPresentationStyle = .fullScreen
        present(containerViewController, animated: true, completion: nil)
    }
}
