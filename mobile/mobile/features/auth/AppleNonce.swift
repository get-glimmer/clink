import Foundation
import CryptoKit

/**
 * Helpers for the Sign in with Apple nonce.
 *
 * Apple requires a nonce to prevent replay attacks: the SHA256 hash is sent to
 * Apple in the authorization request, and the original raw value is sent to
 * Supabase alongside the identity token so it can verify the match.
 */
enum AppleNonce {
    /// Generates a cryptographically random nonce string.
    static func random(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var r: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &r)
                return r
            }
            for r in randoms where remaining > 0 {
                if Int(r) < chars.count * (256 / chars.count) {
                    result.append(chars[Int(r) % chars.count])
                    remaining -= 1
                }
            }
        }
        return result
    }

    /// Returns the lowercase hex SHA256 hash of the given string.
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
