//
//  Movie.swift
//  FlexPlayer
//

import Foundation

struct Movie: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    var metadata: MovieMetadata?
}
