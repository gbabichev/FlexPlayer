//
//  VideoURLItem.swift
//  FlexPlayer
//

import Foundation

struct VideoURLItem: Identifiable, Equatable {
    let url: URL

    var id: String {
        url.absoluteString
    }

    static func == (lhs: VideoURLItem, rhs: VideoURLItem) -> Bool {
        lhs.url == rhs.url
    }
}
