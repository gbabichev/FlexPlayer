//
//  Movie.swift
//  FlexPlayer
//

import Foundation

struct Movie: Identifiable, Hashable {
    let name: String
    let url: URL
    var metadata: MovieMetadata?

    var id: String { url.path }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: Movie, rhs: Movie) -> Bool {
        lhs.url == rhs.url
    }
}
