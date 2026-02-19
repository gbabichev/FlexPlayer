//
//  VideoFile.swift
//  FlexPlayer
//

import Foundation

struct VideoFile: Identifiable, Hashable {
    let name: String
    let url: URL
    var episodeInfo: (season: Int, episode: Int)?
    var metadata: EpisodeMetadata?

    var id: String { url.path }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: VideoFile, rhs: VideoFile) -> Bool {
        lhs.url == rhs.url
    }
}
