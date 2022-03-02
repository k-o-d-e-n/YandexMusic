//
//  Client.swift
//  YandexMusic
//
//  Created by Denis Koryttsev on 24.08.2020.
//

import Foundation
import XMLCoder
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct Response<Result>: Decodable where Result: Decodable {
    let result: Result?
    let error: Error?

    struct Error: Swift.Error, Codable {
        let name: String?
        let error: String?
        let error_description: String?
        let message: String?
    }

    init(_ result: Result) {
        self.result = result
        self.error = nil
    }
    init(error: Error) {
        self.error = error
        self.result = nil
    }
}

public enum SDKHTTPError: Error {
    case noData(Error?)
    case decoding(Error)
}

public final class Client {
    let session: URLSession
    let configuration: Configuration

    public init(_ configuration: Configuration, session: URLSession = .shared) {
        self.session = session
        self.configuration = configuration
    }

    public struct Configuration {
        let baseUrl: URL
        let tokenProvider: AccessTokenProvider

        public init(url: URL, tokenProvider: AccessTokenProvider) {
            self.baseUrl = url
            self.tokenProvider = tokenProvider
        }
    }

    public enum OperationError: Swift.Error {
        case tokenUnavailable
    }

    fileprivate struct DownloadInfo: Codable {
        let host: String
        let path: String
        let ts: String
        let region: String?
        let s: String
    }
    public struct PlayEvent: Codable {
        let playId: String
        let trackId: String
        let from: String
        let albumId: Int
        let playlistId: String?
        let uid: Int?
        let fromCache: Bool?
        let timestamp: Date
        let trackLengthSeconds: Int?
        let totalPlayedSeconds: Int?
        let endPositionSeconds: Int?
        let clientNow: Date?

        public init(
            trackId: String, albumId: Int, from: String, playlistId: String?, fromCache: Bool?,
            playId: String, uid: Int?, timestamp: Date?, trackLength: Int?, totalPlayed: Int?,
            endPosition: Int?, clientNow: Date?
        ) {
            self.trackId = trackId
            self.albumId = albumId
            self.from = from
            self.playlistId = playlistId
            self.fromCache = fromCache
            self.playId = playId
            self.uid = uid
            self.timestamp = timestamp ?? Date()
            self.trackLengthSeconds = trackLength
            self.totalPlayedSeconds = totalPlayed
            self.endPositionSeconds = endPosition
            self.clientNow = clientNow
        }
    }
    public struct FeedbackEvent: Codable {
        public let type: String
        public let timestamp: TimeInterval
        public let from: String?
        public let trackId: String?
        public let totalPlayedSeconds: TimeInterval?

        public init(
            type: String,
            timestamp: TimeInterval,
            from: String?,
            trackId: String?,
            totalPlayedSeconds: TimeInterval?
        ) {
            self.type = type
            self.timestamp = timestamp
            self.from = from
            self.trackId = trackId
            self.totalPlayedSeconds = totalPlayedSeconds
        }
    }
    public struct TrackLikeResult: Decodable {
        public let revision: Int
    }
    public enum Entity: String {
        case track
        case album
        case artist
        case playlist
    }
    public enum LikeAction: String {
        case add = "add-multiple"
        case remove
    }
}
extension Client.Configuration {
    fileprivate func apiUrl(_ components: String...) -> URL {
        components.reduce(baseUrl, { $0.appendingPathComponent($1) })
    }
    fileprivate func apiUrl(_ components: [String]) -> URL {
        components.reduce(baseUrl, { $0.appendingPathComponent($1) })
    }
}
extension Client {
    public func callAPI<R: Decodable>(_ components: String..., placeholder request: URLRequest? = nil, decoder: JSONDecoder = JSONDecoder(), completion: @escaping (Result<R, Error>) -> Void) {
        var urlRequest: URLRequest
        if let placeholder = request {
            urlRequest = placeholder
            var urlComponents = placeholder.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) } ?? URLComponents()
            urlComponents.scheme = configuration.baseUrl.scheme
            urlComponents.host = configuration.baseUrl.host
            urlComponents.path = "/" + configuration.baseUrl.path + components.joined(separator: "/")
            urlComponents.query = placeholder.url?.query
            urlRequest.url = urlComponents.url
        } else {
            urlRequest = URLRequest(url: configuration.apiUrl(components))
        }

        guard let token = configuration.tokenProvider.currentToken else { return completion(.failure(OperationError.tokenUnavailable)) }
        urlRequest.addValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let task = session.response(for: urlRequest, decoder: decoder) { (result: Result<Response<R>, SDKHTTPError>) in
            switch result {
            case .success(let response):
                guard let resp = response.result else {
                    return completion(.failure(response.error!))
                }
                completion(.success(resp))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        task.resume()
    }
    public func likedObjects<Items: Decodable>(ofUserWith userID: String, objectName: String, decoder: JSONDecoder, completion: @escaping (Result<Items, Error>) -> Void) {
        callAPI("users", userID, "likes", objectName, decoder: decoder, completion: completion)
    }
}

extension Client {
    public func playlists(ofUserWith userID: String, completion: @escaping (Result<[UserPlaylist], Error>) -> Void) {
        var urlRequest = URLRequest(url: configuration.apiUrl("users", userID, "playlists", "list"))

        guard let token = configuration.tokenProvider.currentToken else { return completion(.failure(OperationError.tokenUnavailable)) }
        urlRequest.addValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let task = session.response(for: urlRequest, decoder: decoder) { (result: Result<Response<[UserPlaylist]>, SDKHTTPError>) in
            switch result {
            case .success(let response):
                guard let resp = response.result else {
                    return completion(.failure(response.error!))
                }
                completion(.success(resp))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        task.resume()
    }
    public func tracks(ofPlaylistWith playlistKind: String, userID: String, completion: @escaping (Result<UserPlaylist, Error>) -> Void) {
        var urlRequest = URLRequest(url: configuration.apiUrl("users", userID, "playlists", playlistKind))

        guard let token = configuration.tokenProvider.currentToken else { return completion(.failure(OperationError.tokenUnavailable)) }
        urlRequest.addValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let task = session.response(for: urlRequest, decoder: decoder) { (result: Result<Response<UserPlaylist>, SDKHTTPError>) in
            switch result {
            case .success(let response):
                guard let resp = response.result else {
                    return completion(.failure(response.error!))
                }
                completion(.success(resp))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        task.resume()
    }
    @discardableResult
    public func downloadInfo(ofTrackWith trackID: String, completion: @escaping (Result<[Track.DownloadInfo], Error>) -> Void) -> URLSessionTask? {
        var urlRequest = URLRequest(url: configuration.apiUrl("tracks", trackID, "download-info"))
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData

        guard let token = configuration.tokenProvider.currentToken else { completion(.failure(OperationError.tokenUnavailable)); return nil }
        urlRequest.addValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let task = session.response(for: urlRequest) { (result: Result<Response<[Track.DownloadInfo]>, SDKHTTPError>) in
            switch result {
            case .success(let response):
                guard let resp = response.result else {
                    return completion(.failure(response.error!))
                }
                completion(.success(resp))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        task.resume()
        return task
    }
    @discardableResult
    public func downloadURL(by url: URL, codec: String, completion: @escaping (Result<URL, Error>) -> Void) -> URLSessionTask? {
        var urlRequest = URLRequest(url: url)
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        guard let token = configuration.tokenProvider.currentToken else { completion(.failure(OperationError.tokenUnavailable)); return nil }
        urlRequest.addValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let task = session.dataTask(with: urlRequest) { (data, response, error) in
            guard let dat = data else { return completion(.failure(SDKHTTPError.noData(error))) }
            do {
                let info = try XMLDecoder().decode(DownloadInfo.self, from: dat)
                let sign = MD5(string: "XGRlBW9FXlekgbPrRHuSiA" + info.path[info.path.index(after: info.path.startIndex)...] + info.s).map { String(format: "%02hhx", $0) }.joined()

                guard let url = URL(string: "https://\(info.host)/get-\(codec)/\(sign)/\(info.ts)\(info.path)")
                else { return completion(.failure(SDKHTTPError.decoding(NSError(domain: "xml", code: 1, userInfo: nil)))) }
                completion(.success(url))
            } catch {
                completion(.failure(SDKHTTPError.decoding(NSError(domain: "xml", code: 0, userInfo: nil))))
            }
        }
        task.resume()
        return task
    }
}
extension Client {
    public func tracks(with ids: [String], completion: @escaping (Result<[Track], Error>) -> Void) {
        var requestPlaceholder = URLRequest(
            url: URL(string: "http://placeholder.com?trackIds=" + ids.joined(separator: ","))!
        )
        requestPlaceholder.httpMethod = "POST"
        callAPI("tracks", placeholder: requestPlaceholder, completion: completion)
    }
    public func feed(completion: @escaping (Result<Feed, Error>) -> Void) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        callAPI("feed", decoder: decoder, completion: completion)
    }
    public func likedTracks(ofUserWith userID: String, completion: @escaping (Result<LikedTracks, Error>) -> Void) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        likedObjects(ofUserWith: userID, objectName: "tracks", decoder: decoder, completion: completion)
    }
}
extension Client {
    public func sendPlay(_ event: PlayEvent, completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: URL(string: "http://placeholder.com")!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        encoder.keyEncodingStrategy = .convertToKebabCase
        request.httpBody = (try! JSONSerialization.jsonObject(with: encoder.encode(event), options: .allowFragments) as! NSDictionary)
            .map({ "\($0.key)=\($0.value)" })
            .joined(separator: "&")
            .data(using: .utf8)
        request.addValue("\(request.httpBody!.count)", forHTTPHeaderField: "Content-Length")
        callAPI("play-audio", placeholder: request, completion: completion)
    }
    public func sendRadio(event: FeedbackEvent, forStationWith id: RadioStation.ID, batchID: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: URL(string: "https://www.placeholder.com" + (batchID.map { "?batch-id=\($0)" } ?? ""))!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONEncoder().encode(event)
        callAPI("/rotor/station/\(id.type):\(id.tag)/feedback", placeholder: request, completion: completion)
    }
}
extension Client {
    public func stationsDashboard(completion: @escaping (Result<RadioDashboard, Error>) -> Void) {
        callAPI("rotor", "stations", "dashboard", completion: completion)
    }
    public func queue(forStationWith stationId: RadioStation.ID, last trackId: String? = nil, useSetting2: Bool? = nil, completion: @escaping (Result<StationTracksResult, Error>) -> Void) {
        var urlComponents = URLComponents(string: "http://placeholder.com")!
        urlComponents.query = (["settings2": useSetting2, "queue": trackId] as [String: Any?])
            .compactMapValues({ $0 })
            .map({ "\($0.key)=\($0.value)" })
            .joined(separator: "&")
        let requestPlaceholder = URLRequest(url: urlComponents.url!)
        callAPI("rotor", "station", "\(stationId.type):\(stationId.tag)", "tracks", placeholder: requestPlaceholder, completion: completion)
    }
    public func supplement(forTrackWith id: String, completion: @escaping (Result<Supplement, Error>) -> Void) {
        callAPI("tracks/\(id)/supplement", completion: completion)
    }
}
extension Client {
    public func playlist(change: PlaylistChange, userID: String, completion: @escaping (Result<UserPlaylist, Error>) -> Void) {
        var request = URLRequest(url: URL(string: "https://placeholder.com")!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = (try! JSONSerialization.jsonObject(with: JSONEncoder().encode(change), options: .allowFragments) as! NSDictionary)
            .map({ "\($0.key)=\($0.value)" })
            .joined(separator: "&")
            .data(using: .utf8)
        request.addValue("\(request.httpBody!.count)", forHTTPHeaderField: "Content-Length")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        callAPI("users/\(userID)/playlists/\(change.kind)/change", placeholder: request, decoder: decoder, completion: completion)
    }
    public func like(action: LikeAction, for entities: Entity, with ids: [String], userID: String, completion: @escaping (Result<TrackLikeResult, Error>) -> Void) {
        var request = URLRequest(url: URL(string: "http://placeholder.com?\(entities)Ids=" + ids.joined(separator: ","))!)
        request.httpMethod = "POST"
        callAPI("users/\(userID)/likes/tracks/\(action)", placeholder: request, completion: completion)
    }
}
