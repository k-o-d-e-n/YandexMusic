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

/// Kebab-case support from `https://github.com/Fleuronic/Skewer`

private struct AnyKey {
    let stringValue: String
    let intValue: Int?
}

extension AnyKey: CodingKey {
    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension JSONEncoder.KeyEncodingStrategy {
    static var convertToKebabCase: Self {
        .custom { keys in
            let stringValue = keys.last!.stringValue
            let convertedStringValue = stringValue.convertedToKebabCase
            return AnyKey(stringValue: convertedStringValue)!
        }
    }
}

extension String {
    var convertedToKebabCase: Self {
        guard !isEmpty else { return self }

        var wordStart = startIndex
        var wordRanges: [Range<Index>] = []
        var searchRange = index(after: wordStart)..<endIndex

        while let uppercaseRange = rangeOfCharacter(from: .uppercaseLetters, range: searchRange) {
            wordRanges.append(wordStart..<uppercaseRange.lowerBound)
            searchRange = uppercaseRange.lowerBound..<searchRange.upperBound

            guard let lowercaseRange = rangeOfCharacter(from: .lowercaseLetters, range: searchRange) else {
                wordStart = searchRange.lowerBound
                break
            }

            let nextCharacterAfterCapital = index(after: uppercaseRange.lowerBound)
            searchRange = lowercaseRange.upperBound..<searchRange.upperBound

            if lowercaseRange.lowerBound == nextCharacterAfterCapital {
                wordStart = uppercaseRange.lowerBound
            } else {
                let beforeLowerIndex = index(before: lowercaseRange.lowerBound)
                wordRanges.append(uppercaseRange.lowerBound..<beforeLowerIndex)
                wordStart = beforeLowerIndex
            }
        }
        wordRanges.append(wordStart..<searchRange.upperBound)

        let words = wordRanges.map { self[$0] }
        let lowercaseWords = words.map { $0.lowercased() }
        let result = lowercaseWords.joined(separator: "-")

        return result
    }
}
