//
//  ColorExtension.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI
import AppKit

extension Color {
    func components() -> (red: Double, green: Double, blue: Double, alpha: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard let color = NSColor(self).usingColorSpace(.deviceRGB) else {
            return (0.5, 0.5, 0.5, 1)
        }
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
