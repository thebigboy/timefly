import UIKit
import SwiftUI

extension Color {
    init?(hex: String?) {
        guard let hex, let ui = UIColor(hex: hex) else { return nil }
        self = Color(ui)
    }
    func toHexString() -> String? { UIColor(self).toHexString() }
}

extension UIColor {
    convenience init?(hex: String) {
        var s = hex.replacingOccurrences(of: "#", with: "")
        if s.count == 6 { s.append("FF") }
        guard s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 24) & 0xFF) / 255.0
        let g = CGFloat((v >> 16) & 0xFF) / 255.0
        let b = CGFloat((v >> 8) & 0xFF) / 255.0
        let a = CGFloat(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: a)
    }
    func toHexString() -> String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let v = (Int(r*255)<<24) | (Int(g*255)<<16) | (Int(b*255)<<8) | Int(a*255)
        return String(format: "#%08X", v)
    }
}
