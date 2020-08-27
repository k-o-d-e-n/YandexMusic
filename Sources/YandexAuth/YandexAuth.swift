//
//  YandexAuth.swift
//  YandexMusic
//
//  Created by Denis Koryttsev on 25.08.2020.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct Account: Codable {
    let uid: Int
    let region: Int
    let login: String
    let fullName: String
    let secondName: String
    let firstName: String
    let displayName: String
    let hostedUser: Bool
    let birthday: Date
    let registeredAt: Date
}

public final class YandexAuth {
    private let clientID: String
    private let clientSecret: String?

    public init(clientID: String, secret: String?) {
        self.clientID = clientID
        self.clientSecret = secret
    }

    public struct AccessToken: Codable {
        public let value: String
        public let expired: Date
        public let tokenType: String
        public let uid: Int?
        public var username: String?

        public init(value: String, expired: Date, type: String, uid: Int?, username: String?) {
            self.value = value
            self.expired = expired
            self.tokenType = type
            self.uid = uid
            self.username = username
        }

        enum CodingKeys: String, CodingKey {
            case value = "access_token"
            case expired = "expires_in"
            case tokenType = "token_type"
            case uid
            case username
        }

        public init(with decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.value = try container.decode(String.self, forKey: .value)
            self.expired = try Date(timeIntervalSinceNow: container.decode(TimeInterval.self, forKey: .expired))
            self.tokenType = try container.decode(String.self, forKey: .tokenType)
            self.uid = try container.decodeIfPresent(Int.self, forKey: .uid)
            self.username = try container.decodeIfPresent(String.self, forKey: .username)
        }
    }

    public struct ErrorResponse: Swift.Error, Codable {
        let error: String
        let error_description: String?
    }

    public enum OperationError: Error {
        case noData
        case apiError(ErrorResponse)
        case decoding(Error)
    }
}

internal extension YandexAuth {
    var clientValues: [String: String] {
        var values = ["client_id": clientID]
        if let secret = clientSecret {
            values["client_secret"] = secret
        }
        return values
    }
}

public extension YandexAuth {
    func auth(with username: String, password: String, completion: @escaping (Result<AccessToken, OperationError>) -> Void) {
        var urlRequest = URLRequest(url: URL(string: "https://oauth.yandex.ru/token")!)
        urlRequest.httpMethod = "POST"
        var bodyValues = clientValues
        bodyValues["grant_type"] = "password"
        bodyValues["username"] = username
        bodyValues["password"] = password
        urlRequest.httpBody = bodyValues
            .map({ "\($0.key)=\($0.value)" }).joined(separator: "&")
            .data(using: .utf8)

        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        headers["Content-Length"] = "\(urlRequest.httpBody!.count)"
        urlRequest.allHTTPHeaderFields = headers

        let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            guard let dat = data else { return completion(.failure(.noData)) }
            do {
                guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) != false else {
                    let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: dat)
                    return completion(.failure(.apiError(errorResponse)))
                }
                let token = try JSONDecoder().decode(AccessToken.self, from: dat)
                completion(.success(token))
            } catch {
                completion(.failure(.decoding(error)))
            }
        }
        task.resume()
    }
}
