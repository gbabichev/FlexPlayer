//
//  Show.swift
//  FlexPlayer
//

import Foundation

struct Show: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let files: [VideoFile]
    var metadata: ShowMetadata?
}
