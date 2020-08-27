//
//  AccessTokenProvider.swift
//  YandexMusic
//
//  Created by Denis Koryttsev on 24.08.2020.
//

public protocol AccessTokenProvider {
    var currentToken: String? { get }

    func getAccessToken(_ completion: @escaping (Result<String, Error>) -> Void)
}
