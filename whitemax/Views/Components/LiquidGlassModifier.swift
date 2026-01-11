//
//  LiquidGlassModifier.swift
//  whitemax
//

import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 18
    var material: Material = .ultraThinMaterial

    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 18, material: Material = .ultraThinMaterial) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, material: material))
    }
}

