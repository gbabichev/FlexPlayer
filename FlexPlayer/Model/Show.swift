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
        hasher.combine(Int(metadata?.lastUpdated.timeIntervalSince1970 ?? 0))
        hasher.combine(files.count)
        for file in files.sorted(by: { $0.url.path < $1.url.path }) {
            hasher.combine(file.url.path)
            hasher.combine(Int(file.metadata?.lastUpdated.timeIntervalSince1970 ?? 0))
        }
    }

    static func == (lhs: Show, rhs: Show) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard Int(lhs.metadata?.lastUpdated.timeIntervalSince1970 ?? 0) ==
              Int(rhs.metadata?.lastUpdated.timeIntervalSince1970 ?? 0) else {
            return false
        }

        let lhsFileSignature = lhs.files
            .sorted(by: { $0.url.path < $1.url.path })
            .map { "\($0.url.path)#\(Int($0.metadata?.lastUpdated.timeIntervalSince1970 ?? 0))" }
        let rhsFileSignature = rhs.files
            .sorted(by: { $0.url.path < $1.url.path })
            .map { "\($0.url.path)#\(Int($0.metadata?.lastUpdated.timeIntervalSince1970 ?? 0))" }

        return lhsFileSignature == rhsFileSignature
    }
}
