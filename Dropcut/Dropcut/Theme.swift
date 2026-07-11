//
//  Theme.swift
//  Dropcut
//
//  Created by Antigravity on 7/11/26.
//

import SwiftUI

extension Color {
    /// Safelight Crimson Red - represents darkroom safelight illumination
    static let themePrimary = Color(red: 0.73, green: 0.11, blue: 0.11)
    
    /// Chemical Amber Gold - represents photographic development chemicals
    static let themeSecondary = Color(red: 0.85, green: 0.47, blue: 0.02)
    
    /// Accent safelight glow
    static let themeAccent = Color(red: 0.95, green: 0.60, blue: 0.10)
}

extension LinearGradient {
    /// Standard theme gradient running horizontally from Crimson Red to Chemical Amber
    static var themeGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.themePrimary, .themeSecondary]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    /// Helper to create a theme gradient with custom direction points
    static func themeGradient(startPoint: UnitPoint = .leading, endPoint: UnitPoint = .trailing) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.themePrimary, .themeSecondary]),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
    
    /// Soft translucent theme gradient for background glowing shapes/circles
    static var themeSoftGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.themePrimary.opacity(0.15), .themeSecondary.opacity(0.1)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Font {
    /// Serif font for main logos/headers to feel elevated and editorial
    static func themeSerif(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
