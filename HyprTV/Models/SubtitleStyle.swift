import Foundation
import SwiftUI

/// Persisted subtitle appearance preferences.
@Observable
final class SubtitleStyle {

    // MARK: - Keys

    private static let fontSizeKey = "subtitle_font_size"
    private static let fontNameKey = "subtitle_font_name"
    private static let textColorKey = "subtitle_text_color"
    private static let backgroundEnabledKey = "subtitle_bg_enabled"
    private static let backgroundOpacityKey = "subtitle_bg_opacity"
    private static let outlineEnabledKey = "subtitle_outline_enabled"
    private static let delayMsKey = "subtitle_delay_ms"

    private let defaults = UserDefaults.standard

    // MARK: - Properties

    /// Font size in points (16-72).
    var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Self.fontSizeKey) }
    }

    /// Font family name.
    var fontName: String {
        didSet { defaults.set(fontName, forKey: Self.fontNameKey) }
    }

    /// Text color as a hex string.
    var textColorHex: String {
        didSet { defaults.set(textColorHex, forKey: Self.textColorKey) }
    }

    /// Whether to show a semi-transparent background behind subtitle text.
    var backgroundEnabled: Bool {
        didSet { defaults.set(backgroundEnabled, forKey: Self.backgroundEnabledKey) }
    }

    /// Background opacity (0.0-1.0).
    var backgroundOpacity: Double {
        didSet { defaults.set(backgroundOpacity, forKey: Self.backgroundOpacityKey) }
    }

    /// Whether to render an outline/stroke around subtitle text.
    var outlineEnabled: Bool {
        didSet { defaults.set(outlineEnabled, forKey: Self.outlineEnabledKey) }
    }

    /// Subtitle delay in milliseconds (positive = later, negative = earlier).
    var delayMs: Int {
        didSet { defaults.set(delayMs, forKey: Self.delayMsKey) }
    }

    // MARK: - Init

    init() {
        let d = UserDefaults.standard

        let storedFontSize = d.double(forKey: Self.fontSizeKey)
        self.fontSize = storedFontSize > 0 ? storedFontSize : 42

        self.fontName = d.string(forKey: Self.fontNameKey) ?? "System"
        self.textColorHex = d.string(forKey: Self.textColorKey) ?? "#FFFFFF"

        self.backgroundEnabled = d.object(forKey: Self.backgroundEnabledKey) == nil ? true : d.bool(forKey: Self.backgroundEnabledKey)

        let storedOpacity = d.double(forKey: Self.backgroundOpacityKey)
        self.backgroundOpacity = (storedOpacity > 0 || d.object(forKey: Self.backgroundOpacityKey) != nil) ? storedOpacity : 0.6

        self.outlineEnabled = d.object(forKey: Self.outlineEnabledKey) == nil ? true : d.bool(forKey: Self.outlineEnabledKey)
        self.delayMs = d.integer(forKey: Self.delayMsKey)
    }

    // MARK: - VLC Options

    /// Returns VLC command-line options for subtitle rendering.
    func vlcSubtitleOptions() -> [String: Any] {
        var opts: [String: Any] = [:]

        // Font
        if fontName != "System" {
            opts["--freetype-font"] = fontName
        }
        opts["--freetype-fontsize"] = Int(fontSize)

        // Color (VLC uses decimal RGB)
        if let colorInt = hexToDecimal(textColorHex) {
            opts["--freetype-color"] = colorInt
        }

        // Outline
        if outlineEnabled {
            opts["--freetype-outline-thickness"] = 2
            opts["--freetype-outline-color"] = 0 // black outline
        } else {
            opts["--freetype-outline-thickness"] = 0
        }

        // Background
        if backgroundEnabled {
            opts["--freetype-background-opacity"] = Int(backgroundOpacity * 255)
            opts["--freetype-background-color"] = 0 // black background
        } else {
            opts["--freetype-background-opacity"] = 0
        }

        // Delay
        if delayMs != 0 {
            opts["--sub-delay"] = delayMs * 10 // VLC uses 1/10ths of a second... actually milliseconds
        }

        return opts
    }

    // MARK: - Available Fonts

    static let availableFonts: [(name: String, displayName: String)] = [
        ("System", "System Default"),
        ("Helvetica Neue", "Helvetica Neue"),
        ("Arial", "Arial"),
        ("Avenir Next", "Avenir Next"),
        ("Georgia", "Georgia"),
        ("Menlo", "Menlo (Monospace)"),
        ("Courier New", "Courier New"),
        ("Futura", "Futura"),
        ("Verdana", "Verdana"),
    ]

    /// Available text colors.
    static let availableColors: [(hex: String, name: String)] = [
        ("#FFFFFF", "White"),
        ("#FFFF00", "Yellow"),
        ("#00FF00", "Green"),
        ("#00FFFF", "Cyan"),
        ("#FF6B6B", "Coral"),
        ("#FFB347", "Orange"),
        ("#DDA0DD", "Plum"),
    ]

    // MARK: - Helpers

    private func hexToDecimal(_ hex: String) -> Int? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6 else { return nil }
        return Int(cleaned, radix: 16)
    }
}
