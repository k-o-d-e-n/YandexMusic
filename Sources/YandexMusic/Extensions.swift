//
//  Extensions.swift
//  YandexMusic
//
//  Created by Denis Koryttsev on 24.08.2020.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLSession {
    func response<R: Decodable>(for urlRequest: URLRequest, decoder: JSONDecoder = JSONDecoder(), completion: @escaping (Result<Response<R>, SDKHTTPError>) -> Void) -> URLSessionDataTask {
        let task = dataTask(with: urlRequest) { data, response, error in
            guard let dat = data else { return completion(.failure(.noData(error))) }
            do {
                let body = try decoder.decode(Response<R>.self, from: dat)
                completion(.success(body))
            } catch {
                completion(.failure(.decoding(error)))
            }
        }
        return task
    }
}
