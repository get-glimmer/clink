//
//  String+Emoji.swift
//  mobile
//
//  Shared emoji detection helpers.
//

import Foundation

extension String {
    var isEmojiOnly: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        for scalar in trimmed.unicodeScalars {
            if !scalar.properties.isEmoji { return false }
        }
        return true
    }

    var firstEmoji: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        for scalar in trimmed.unicodeScalars {
            if scalar.properties.isEmoji { return String(scalar) }
        }
        return nil
    }
}


