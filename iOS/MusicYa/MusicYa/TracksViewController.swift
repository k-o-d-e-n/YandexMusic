//
//  TracksViewController.swift
//  MusicYa
//
//  Created by Denis Koryttsev on 28.11.2020.
//

import UIKit
import YandexMusic

final class TrackCell: UITableViewCell {
    lazy var downloadButton: UIButton = UIButton(autolayout: true).add(to: contentView) { btn in
        btn.layer.cornerRadius = 5
        btn.clipsToBounds = true
        btn.setTitle("Save", for: .normal)
        btn.contentEdgeInsets = UIEdgeInsets(horizontal: 4, vertical: 2)
        btn.setBackgroundImage(UIImage.colored(by: tintColor.cgColor), for: .normal)
        NSLayoutConstraint.activate([
            btn.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            btn.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    lazy var progressView: UIProgressView = UIProgressView(autolayout: true).add(to: contentView) { pv in
        pv.isHidden = true
        let width = "Save".boundingRect(with: .zero, options: [], attributes: [.font: downloadButton.titleLabel?.font as Any], context: nil).width + 8
        NSLayoutConstraint.activate([
            pv.widthAnchor.constraint(equalToConstant: width),
            pv.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            pv.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        backgroundView = UIView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        downloadButton.isHidden = false
        progressView.isHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let tl = textLabel {
            tl.frame.size.width = min(tl.frame.width, downloadButton.frame.minX - tl.frame.minX - 5)
            if let dtl = detailTextLabel {
                dtl.frame.size.width = min(dtl.frame.width, downloadButton.frame.minX - dtl.frame.minX - 5)
            }
        }
    }
}
extension UITableView {
    @objc func setEditingAction() {
        setEditing(!isEditing, animated: true)
    }
}

final class TracksViewController: UITableViewController {
    let queue: PlayerQueue
    let completion: (PlayerQueue) -> Void

    var displayValues: [Track]?
    var movable: (index: Int, item: Track)?
    var shouldCloseOnSelect: Bool = true
    var style: Style = .transparent
    var currentList: [Track] { displayValues ?? queue.tracks }

    override var navigationBarColor: UIColor? {
        switch style {
        case .system: return view.backgroundColor
        case .transparent: return .white
        }
    }

    enum Style {
        case system
        case transparent
    }

    init(queue: PlayerQueue, movable: (index: Int, item: Track)? = nil, completion: @escaping (PlayerQueue) -> Void) {
        self.queue = queue
        self.completion = completion
        self.movable = movable
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        switch style {
        case .transparent:
            tableView.backgroundColor = nil
            tableView.backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
        case .system: break
        }

        tableView.register(TrackCell.self, forCellReuseIdentifier: "cell")

        if movable != nil {
            tableView.isEditing = true
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonAction))
        } else {
            if queue.editor != nil {
                let editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: tableView, action: #selector(UITableView.setEditingAction))
                editButton.tintColor = ApplicationState.contraTintColor
                navigationItem.rightBarButtonItems = navigationItem.rightBarButtonItems.map { $0 + [editButton] } ?? [editButton]
            }

            let searchBar = UISearchBar()
            navigationItem.titleView = searchBar
            searchBar.placeholder = "Search"
            searchBar.delegate = self
            searchBar.searchBarStyle = .minimal
        }

        if queue.tracks.isEmpty {
            tableView.refreshControl?.beginRefreshing()
            queue.prepare { [weak self] (_) in
                guard let `self` = self else { return }
                DispatchQueue.main.async {
                    self.tableView.refreshControl?.endRefreshing()
                    self.tableView.reloadData()
                    if self.movable?.index == 0 {
                        self.movable?.index = self.queue.tracks.count
                        self.tableView.scrollToRow(at: IndexPath(row: self.queue.tracks.count, section: 0), at: .bottom, animated: true)
                    }
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let currentIndex = queue.currentTrackIndex ?? movable?.index {
            tableView.scrollToRow(at: IndexPath(row: currentIndex, section: 0), at: .middle, animated: true)
        }
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        defaultScrollViewDidScroll(scrollView)
    }

    func close() {
        if isPresented {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc private func doneButtonAction() {
        close()
        queue.currentTrackIndex = movable?.index
        completion(queue)
    }

    @objc private func downloadButtonTouchUpInside(_ btn: UIButton) {
        guard case let cell as TrackCell = btn.superview?.superview, let indexPath = tableView.indexPath(for: cell) else { return }
        let track = queue.tracks[indexPath.row]
        let needDownload = !queue.shouldPreloadTrackData
        let cacheFile = queue.cacheFolder.appendingPathComponent(track.downloadTrackID, isDirectory: false)
        let progress: Progress = Progress(totalUnitCount: 10)
        let progress1 = queue.prepare(at: queue.tracks.firstIndex(of: track) ?? indexPath.row) { (result) in
            switch result {
            case .success(let url):
                guard needDownload else { return }
                let urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: .infinity)
                let task = URLSession.shared.downloadTask(with: urlRequest, completionHandler: { (fileUrl, response, error) in
                    if let fUrl = fileUrl {
                        do {
                            try FileManager.default.copyItem(at: fUrl, to: cacheFile)
                            print("Downloaded", cacheFile)
                        } catch {
                            print(NSError(domain: "cannot-open-file", code: 0, userInfo: nil))
                        }
                    } else {
                        print(error ?? NSError(domain: "cannot-download-file", code: 0, userInfo: nil))
                    }
                })
                progress.addChild(task.progress, withPendingUnitCount: 6)
                task.resume()
            case .failure(let error): print(error)
            }
        }
        guard let downloadProgress = progress1 else { return }
        progress.addChild(downloadProgress, withPendingUnitCount: needDownload ? 4 : 10)
        cell.progressView.isHidden = false
        cell.downloadButton.isHidden = true
        cell.progressView.observedProgress = progress
    }
}
extension TracksViewController: UISearchBarDelegate {
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { currentList.count + (movable.map({ _ in 1 }) ?? 0) }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let track = movable
            .flatMap({ $0.index == indexPath.row ? $0 : ((indexPath.row - ($0.index < indexPath.row ? 1 : 0), nil)) })
            .map({ $0.1 ?? currentList[$0.0] })
            ?? currentList[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TrackCell
        let title = NSMutableAttributedString(string: track.title, attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .semibold)])
        if let artists = track.artists {
            title.append(
                NSAttributedString(
                    string: " — " + artists.map({ $0.name }).joined(separator: ", "),
                    attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .light)]
                )
            )
        }
        cell.textLabel?.attributedText = title
        cell.detailTextLabel?.text = track.albums?.map({ $0.title }).joined(separator: ", ")
        if !tableView.isEditing {
            if cell.downloadButton.allTargets.isEmpty {
                cell.downloadButton.addTarget(self, action: #selector(downloadButtonTouchUpInside(_:)), for: .touchUpInside)
            }
            let cacheFile = queue.cacheFolder.appendingPathComponent(track.downloadTrackID, isDirectory: false)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: cacheFile.relativePath, isDirectory: &isDirectory), !isDirectory.boolValue {
                cell.progressView.isHidden = false
                cell.progressView.progress = 1.0
                cell.downloadButton.isHidden = true
            } else {
                cell.progressView.isHidden = true
            }
        } else {
            cell.downloadButton.isHidden = true
        }
        cell.backgroundColor = (queue.currentTrackIndex ?? movable?.index).flatMap({ indexPath.row == $0 ? cell.tintColor.withAlphaComponent(0.5) : nil })
        cell.downloadButton.isHidden = !track.available
        cell.textLabel?.alpha = track.available ? 1.0 : 0.5
        cell.detailTextLabel?.alpha = track.available ? 1.0 : 0.5
        switch style {
        case .transparent:
            #if targetEnvironment(macCatalyst)
            cell.textLabel?.textColor = .black
            cell.detailTextLabel?.textColor = .black
            #endif
        case .system: break
        }
        
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let track = currentList[indexPath.row]
        queue.currentTrackIndex = queue.tracks.firstIndex(of: track) ?? indexPath.row

        if shouldCloseOnSelect {
            close()
        }
        completion(queue)
    }
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard movable != nil else {
            guard currentList[indexPath.row].available else { return nil }
            return indexPath
        }
        return nil
    }
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        movable == nil ? .delete : .none
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            let track = currentList[indexPath.row]
            let index = queue.tracks.firstIndex(of: track) ?? indexPath.row
            queue.editor?.change([.delete(index)], completion: { (result) in
                switch result {
                case .failure(let error): print("Deletion fails \(error)")
                case .success:
                    print("Deleted track with title: \(track.title)")
                    DispatchQueue.main.async {
                        tableView.performBatchUpdates {
                            tableView.deleteRows(at: [indexPath], with: .automatic)
                        }
                    }
                }
            })
        default: break
        }
    }
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard let movable = movable else { return false }
        return movable.index == indexPath.row
    }
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        movable?.index = destinationIndexPath.row
    }
    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        #if targetEnvironment(macCatalyst)
        guard
            tableView.contentSize.height > tableView.frame.height,
            let visibleRows = tableView.indexPathsForVisibleRows, visibleRows.count > 1
        else { return proposedDestinationIndexPath }
        let topIndex = navigationController.map({ $0.isNavigationBarHidden ? 1 : 2 }) ?? 1
        let destinationIndexPath: IndexPath
        if visibleRows[visibleRows.count - 2] == proposedDestinationIndexPath, visibleRows[visibleRows.count - 1].row < currentList.count {
            destinationIndexPath = IndexPath(row: visibleRows[visibleRows.count - 1].row + 1, section: proposedDestinationIndexPath.section)
            tableView.scrollToRow(at: destinationIndexPath, at: .bottom, animated: false)
        } else if visibleRows[topIndex] == proposedDestinationIndexPath {
            if visibleRows[0].row == 0 {
                destinationIndexPath = proposedDestinationIndexPath
                tableView.scrollToRow(at: visibleRows[0], at: .top, animated: false)
            } else {
                destinationIndexPath = IndexPath(row: visibleRows[0].row - 1, section: proposedDestinationIndexPath.section)
                tableView.scrollToRow(at: destinationIndexPath, at: .top, animated: false)
            }
        } else {
            destinationIndexPath = proposedDestinationIndexPath
        }
        return destinationIndexPath
        #else
        return proposedDestinationIndexPath
        #endif
    }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if let txt = searchBar.text, txt.count > 0 {
            displayValues = queue.tracks.filter({ (track) -> Bool in
                track.title.contains(txt)
            })
        } else {
            displayValues = nil
        }
        tableView.reloadData()
    }
}

protocol ListItem: Equatable {
    var label: String { get }
}

class ItemListViewController<Item>: UITableViewController, UISearchBarDelegate where Item: ListItem {
    let values: [Item]
    var displayValues: [Item]?
    var movableItem: (index: Int, item: Item)?
    private var completion: (((index: Int, item: Item)?) -> Void)?
    private var currentList: [Item] { displayValues ?? values }
    var shouldCloseOnSelect: Bool = true

    init(_ items: [Item], movable item: Item? = nil, completion: @escaping ((index: Int, item: Item)?) -> Void) {
        self.values = items
        self.completion = completion
        self.movableItem = item.map({ (0, $0) })
        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let searchBar = UISearchBar()
        navigationItem.titleView = searchBar
        searchBar.placeholder = "Search"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal

        tableView.keyboardDismissMode = .interactive
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    private func close(with result: (index: Int, item: Item)?) {
        let compl = completion
        if shouldCloseOnSelect {
            if isPresented {
                dismiss(animated: true)
            } else {
                navigationController?.popViewController(animated: true)
            }
            completion = nil
        }
        compl?(result)
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        defaultScrollViewDidScroll(scrollView)
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
        if let compl = self.completion {
            compl(nil)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        currentList.count + (movableItem.map({ _ in 1 }) ?? 0)
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let model = movableItem
            .flatMap({ $0.index == indexPath.row ? $0 : ((indexPath.row - ($0.index < indexPath.row ? 1 : 0), nil)) })
            .map({ $0.1 ?? currentList[$0.0] })
            ?? currentList[indexPath.row]
        cell.textLabel?.text = model.label
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let moved = movableItem, indexPath.row == moved.index else {
            let item = currentList[indexPath.row]
            close(with: (index: values.firstIndex(of: item)!, item: item))
            return
        }
        close(with: moved)
    }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if let txt = searchBar.text, txt.count > 0 {
            displayValues = values.filter({ (country) -> Bool in
                return country.label.contains(txt)
            })
        } else {
            displayValues = nil
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard let movable = movableItem else { return false }
        return movable.index == indexPath.row
    }
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        movableItem?.index = destinationIndexPath.row
    }
}
