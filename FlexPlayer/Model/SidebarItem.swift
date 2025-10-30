//
//  SidebarItem.swift
//  FlexPlayer
//

import Foundation

// Enum to represent sidebar items
enum SidebarItem: Identifiable, Hashable {
    case show(Show)
    case movies
    case externalVideos

    var id: String {
        switch self {
        case .show(let show):
            return "show-\(show.id)"
        case .movies:
            return "movies"
        case .externalVideos:
            return "external-videos"
        }
    }
}
