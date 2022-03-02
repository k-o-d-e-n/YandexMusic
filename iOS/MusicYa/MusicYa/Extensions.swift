//
//  Others.swift
//  MusicYa
//
//  Created by Denis Koryttsev on 17.12.2020.
//

import UIKit

extension Double {
    func onNan(_ newValue: Double) -> Double {
        isNaN ? newValue : self
    }
}

extension Collection {
    func cycledIndex(_ i: Index, offsetBy offset: Int) -> Index {
        let (start, limit, distanceLimit) = offset > 0 ? (startIndex, index(endIndex, offsetBy: -1), endIndex) : (endIndex, startIndex, startIndex)
        guard let index = index(i, offsetBy: offset, limitedBy: limit) else {
            let offsetFromStart = offset - distance(from: i, to: distanceLimit)
            return self.cycledIndex(start, offsetBy: offsetFromStart)
        }
        return index
    }
}

extension JSONDecoder {
    func decode<T: Decodable>(from data: Data) throws -> T {
        try decode(T.self, from: data)
    }
}
extension UIViewController {
    convenience init(view: UIView) {
        self.init()
        self.view = view
    }

    @objc func dismissAnimated() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc var navigationBarColor: UIColor? { nil }
    func defaultScrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let navigationBar = navigationController?.navigationBar else { return }
        guard let backgroundColor = navigationBarColor ?? view.backgroundColor else { return }
        let alpha = (scrollView.contentOffset.y + scrollView.adjustedContentInset.top) / 40
        let image: UIImage?
        if alpha <= 0 {
            image = navigationBar.backgroundImage(for: .default).flatMap({ $0.size == .zero ? nil : UIImage() })
        } else if alpha < 1 {
            image = .colored(by: backgroundColor.withAlphaComponent(alpha).cgColor)
        } else if alpha < 2 || navigationBar.backgroundImage(for: .default).flatMap({ $0.size == .zero ? nil : $0 }) == nil {
            image = .colored(by: backgroundColor.cgColor)
        } else {
            image = nil
        }
        if let img = image {
            navigationBar.setBackgroundImage(img, for: .default)
        }
    }
}
extension AutoLayoutItem {
    func dimension(for axis: Axis) -> NSLayoutDimension {
        switch axis {
        case .horizontal: return widthAnchor
        case .vertical: return heightAnchor
        }
    }
}
extension CGRect {
    func dimension(for axis: Axis) -> CGFloat {
        switch axis {
        case .horizontal: return width
        case .vertical: return height
        }
    }
}
enum Axis {
    case horizontal
    case vertical

    var inverted: Axis {
        switch self {
        case .horizontal: return .vertical
        case .vertical: return .horizontal
        }
    }
}

extension UIBarButtonItem {
    static func cancel(_ target: Any?, action: Selector) -> UIBarButtonItem {
        let item: UIBarButtonItem.SystemItem
        if #available(iOS 13.0, *) {
            item = .close
        } else {
            item = .cancel
        }
        let cancelBtn = UIBarButtonItem(barButtonSystemItem: item, target: target, action: action)
//        #if targetEnvironment(macCatalyst)
        cancelBtn.tintColor = ApplicationState.contraTintColor
//        #else
//        cancelBtn.setTitleTextAttributes([.foregroundColor: ApplicationState.contraTintColor], for: .normal)
//        #endif
        return cancelBtn
    }
}

protocol KVOResponsible: AnyObject {
    func addObserver(_ observer: NSObject, forKeyPath keyPath: String, options: NSKeyValueObservingOptions, context: UnsafeMutableRawPointer?)
    func removeObserver(_ observer: NSObject, forKeyPath keyPath: String, context: UnsafeMutableRawPointer?)
}
extension NSObject: KVOResponsible {}

final class KVObserver<Root: KVOResponsible, Value>: NSObject {
    final class Helper: NSObject {
        unowned(unsafe) let obj: Root
        let keyPath: String
        let callback: (Root, Change) -> Void
        var isValid: Bool = true

        init(object: Root, keyPath: String, options: NSKeyValueObservingOptions, callback: @escaping (Root, Change) -> Void) {
            self.obj = object
            self.keyPath = keyPath
            self.callback = callback

            super.init()
            objc_setAssociatedObject(object, associationKey(), self, .OBJC_ASSOCIATION_RETAIN)
            object.addObserver(self, forKeyPath: keyPath, options: options, context: nil)
        }

        deinit {
            invalidate()
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard object as AnyObject === obj, let change = change else { return }
            let rawKind: UInt = change[NSKeyValueChangeKey.kindKey] as! UInt
            let kind = NSKeyValueChange(rawValue: rawKind)!
            let notification = Change(
                kind: kind,
                newValue: change[NSKeyValueChangeKey.newKey] as? Value,
                oldValue: change[NSKeyValueChangeKey.oldKey] as? Value,
                indexes: change[NSKeyValueChangeKey.indexesKey] as! IndexSet?,
                isPrior: change[NSKeyValueChangeKey.notificationIsPriorKey] as? Bool ?? false
            )
            callback(obj, notification)
        }

        func invalidate() {
            guard isValid else { return }
            obj.removeObserver(self, forKeyPath: keyPath, context: nil)
            objc_setAssociatedObject(obj, associationKey(), nil, .OBJC_ASSOCIATION_ASSIGN)
            isValid = false
        }
        private func associationKey() -> UnsafeRawPointer {
            return UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        }
    }

    struct Change {
        public typealias Kind = NSKeyValueChange
        public let kind: NSKeyValueObservedChange<Value>.Kind
        ///newValue and oldValue will only be non-nil if .new/.old is passed to `observe()`. In general, get the most up to date value by accessing it directly on the observed object instead.
        public let newValue: Value?
        public let oldValue: Value?
        ///indexes will be nil unless the observed KeyPath refers to an ordered to-many property
        public let indexes: IndexSet?
        ///'isPrior' will be true if this change observation is being sent before the change happens, due to .prior being passed to `observe()`
        public let isPrior: Bool
    }

    weak var helper: Helper?

    init(object: Root, keyPath: String, options: NSKeyValueObservingOptions, callback: @escaping (Root, Change) -> Void) {
        self.helper = Helper(object: object, keyPath: keyPath, options: options, callback: callback)
    }

    func invalidate() {
        helper?.invalidate()
    }

    deinit {
        invalidate()
    }
}

extension KVOResponsible {
    public func observe<Value>(
        _ keyPath: KeyPath<Self, Value>,
        options: NSKeyValueObservingOptions = [],
        changeHandler: @escaping (Self, KVObserver<Self, Value>.Change) -> Void)
    -> KVObserver<Self, Value> {
        let observer = KVObserver(object: self, keyPath: keyPath._kvcKeyPathString!, options: options, callback: changeHandler)
        return observer
    }
    public func observe<T>(
        _ keyPath: KeyPath<Self, Optional<T>>,
        options: NSKeyValueObservingOptions = [],
        changeHandler: @escaping (Self, KVObserver<Self, Optional<T>>.Change) -> Void)
    -> KVObserver<Self, Optional<T>> {
        let observer = KVObserver(object: self, keyPath: keyPath._kvcKeyPathString!, options: options, callback: changeHandler)
        return observer
    }
}

import AVFoundation

final class DownloadSession: NSObject, AVAssetDownloadDelegate {
    lazy var downloadSession: AVAssetDownloadURLSession = AVAssetDownloadURLSession(configuration: .background(withIdentifier: "default.player"), assetDownloadDelegate: self, delegateQueue: nil)
    var tasksInfo: [URLSessionTask: TaskInfo] = [:]

    struct TaskInfo {
        let destinationFile: URL
        let completion: (Result<URL, Error>) -> Void
        let progress: Progress = Progress(totalUnitCount: 100)
    }

    override init() {
    }

    func task(for url: URL, destinationURL: URL, assetTitle: String? = nil, completion: @escaping (Result<URL, Error>) -> Void) -> (t: AVAssetDownloadTask, i: TaskInfo)? {
        guard
            let task = downloadSession.makeAssetDownloadTask(asset: AVURLAsset(url: url), assetTitle: assetTitle ?? destinationURL.lastPathComponent, assetArtworkData: nil, options: nil)
        else {
            completion(.failure(NSError(domain: "cannot-create-task", code: 0, userInfo: nil)))
            return nil
        }
        let info = TaskInfo(destinationFile: destinationURL, completion: completion)
        tasksInfo[task] = info
        return (task, info)
    }

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let info = tasksInfo[assetDownloadTask] else { fatalError("Undefined task") }
        do {
            try FileManager.default.copyItem(at: location, to: info.destinationFile)
            info.completion(.success(info.destinationFile))
        } catch {
            info.completion(.failure(NSError(domain: "cannot-open-file", code: 0, userInfo: nil)))
        }
    }

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        guard let info = tasksInfo[assetDownloadTask] else { fatalError("Undefined task") }
        var percentageComplete = 0.0
        // Iterate over loaded time ranges
        for value in loadedTimeRanges {
            // Unpack CMTimeRange value
            let loadedTimeRange = value.timeRangeValue
            percentageComplete += loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
        percentageComplete *= 100
        info.progress.completedUnitCount = Int64(percentageComplete)
    }

    func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange, for mediaSelection: AVMediaSelection) {
        guard let info = tasksInfo[aggregateAssetDownloadTask] else { fatalError("Undefined task") }
        var percentageComplete = 0.0
        // Iterate over loaded time ranges
        for value in loadedTimeRanges {
            // Unpack CMTimeRange value
            let loadedTimeRange = value.timeRangeValue;
            percentageComplete +=
                CMTimeGetSeconds(loadedTimeRange.duration) / CMTimeGetSeconds(timeRangeExpectedToLoad.duration);
        }
        percentageComplete *= 100
        info.progress.completedUnitCount = Int64(percentageComplete)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let info = tasksInfo.removeValue(forKey: task) else { fatalError("Undefined task") }
        if let err = error {
            info.completion(.failure(err))
        } else {
            info.progress.completedUnitCount = info.progress.totalUnitCount
        }
    }
}
