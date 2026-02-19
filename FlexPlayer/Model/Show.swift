//
//  Show.swift
//  FlexPlayer
//

import Foundation

struct Show: Identifiable, Hashable {
    let name: String
    let files: [VideoFile]
    var metadata: ShowMetadata?

    var id: String { name }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func == (lhs: Show, rhs: Show) -> Bool {
        lhs.name == rhs.name
    }
}
