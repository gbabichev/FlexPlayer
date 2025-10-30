//
//  HelperFunctions.swift
//  FlexPlayer
//

import Foundation

func getRelativePath(for url: URL) -> String {
    guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return url.lastPathComponent
    }

    let relativePath = url.path.replacingOccurrences(of: documentsURL.path + "/", with: "")
    return relativePath
}
