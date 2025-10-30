//
//  IntExtensions.swift
//  FlexPlayer
//

import Foundation

extension Int {
    var runtimeFormatted: String {
        let hours = self / 60
        let minutes = self % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
