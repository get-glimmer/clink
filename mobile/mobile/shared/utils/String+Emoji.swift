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

enum SystemEmojiLibrary {
    static let showerPool: [String] = {
        var emojis: [String] = []
        emojis.reserveCapacity(1600)

        for value in 0...0x10FFFF {
            guard let scalar = UnicodeScalar(value) else { continue }
            guard scalar.properties.isEmoji else { continue }
            guard !scalar.properties.isEmojiModifier else { continue }
            guard !isRegionalIndicator(scalar) else { continue }
            guard !isASCIIKeycapBase(scalar) else { continue }

            if scalar.properties.isEmojiPresentation {
                emojis.append(String(scalar))
            } else if isStandaloneTextStyleEmoji(scalar) {
                emojis.append(String(scalar) + "\u{FE0F}")
            }
        }

        return Array(Set(emojis)).sorted()
    }()

    static func randomEmoji(fallback: String = "🎉") -> String {
        showerPool.randomElement() ?? fallback
    }

    private static func isRegionalIndicator(_ scalar: UnicodeScalar) -> Bool {
        (0x1F1E6...0x1F1FF).contains(scalar.value)
    }

    private static func isASCIIKeycapBase(_ scalar: UnicodeScalar) -> Bool {
        scalar.value == 0x23 || scalar.value == 0x2A || (0x30...0x39).contains(scalar.value)
    }

    private static func isStandaloneTextStyleEmoji(_ scalar: UnicodeScalar) -> Bool {
        guard scalar.value > 0x00A9 else { return false }
        return !scalar.properties.isEmojiPresentation
    }
}
