//
//  VideoFile.swift
//  FlexPlayer
//

import Foundation

struct VideoFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    var episodeInfo: (season: Int, episode: Int)?
    var metadata: EpisodeMetadata?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VideoFile, rhs: VideoFile) -> Bool {
        lhs.id == rhs.id
    }
}
