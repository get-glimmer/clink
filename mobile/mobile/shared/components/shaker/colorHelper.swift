import UIKit
import SwiftUI

extension UIColor {
    convenience init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let v = Int(str, radix: 16) else { return nil }
        self.init(red:   CGFloat((v >> 16) & 0xFF)/255,
                  green: CGFloat((v >>  8) & 0xFF)/255,
                  blue:  CGFloat( v        & 0xFF)/255,
                  alpha: 1)
    }
    func toHex() -> String {
        guard let c = cgColor.components, c.count >= 3 else { return "#000000" }
        return String(format:"#%02X%02X%02X", Int(c[0]*255), Int(c[1]*255), Int(c[2]*255))
    }
}
extension Color { init?(hex: String?) {
    guard let h = hex, let ui = UIColor(hex: h) else { return nil }
    self.init(ui)
} }
