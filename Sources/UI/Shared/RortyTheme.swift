//
//  RortyTheme.swift
//  PantrixRortySwiftUI
//
//  The accent-colour picker, ported from the UIKit demo with the same four themes and the same hex
//  pairs so the two apps are visually identical.
//

import Observation
import SwiftUI
import UIKit

struct RortyTheme: Identifiable, Equatable {
    let id: String
    let name: String

    /// Kept private and paired: a theme is a light/dark pair, and exposing either half separately is
    /// how one of them ends up used on its own in the wrong appearance.
    private let light: UIColor
    private let dark: UIColor

    fileprivate init(id: String, name: String, light: UInt32, dark: UInt32) {
        self.id = id
        self.name = name
        self.light = UIColor(hex: light)
        self.dark = UIColor(hex: dark)
    }

    /// Resolves per appearance at draw time — one colour that is correct in both light and dark,
    /// rather than two colours the caller has to choose between.
    var accent: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// The vivid half, for the picker's swatch dot — a dot has no background to contrast against, so
    /// letting it resolve dynamically would make it vanish in one of the two appearances.
    var swatch: Color { Color(dark) }

    static let all: [RortyTheme] = [
        RortyTheme(id: "portal_green", name: "Portal Green", light: 0x4E8C28, dark: 0x97CE4C),
        RortyTheme(id: "rick_blue", name: "Rick Blue", light: 0x1E88C4, dark: 0x4FC3E8),
        RortyTheme(id: "morty_yellow", name: "Morty Yellow", light: 0xB0870F, dark: 0xF2D64B),
        RortyTheme(id: "plumbus_pink", name: "Plumbus Pink", light: 0xC23D7A, dark: 0xF06AAE)
    ]

    static let fallback = all[0]
}

/// Holds the selected theme and persists it.
///
/// `@Observable` rather than a plain singleton: the whole app tints from `current`, so a change has
/// to re-render the tree. In UIKit the demo had to reach for `window.tintColor` and rebuild rows by
/// hand; here the tint is declarative and every screen follows automatically.
@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()

    private static let key = "selected_theme_id"

    private(set) var current: RortyTheme

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        current = RortyTheme.all.first { $0.id == saved } ?? .fallback
    }

    func select(_ theme: RortyTheme) {
        current = theme
        UserDefaults.standard.set(theme.id, forKey: Self.key)
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
