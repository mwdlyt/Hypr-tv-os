import SwiftUI

/// Subtitle appearance customization sheet.
/// Allows changing font, size, color, background, outline, and timing delay.
struct SubtitleStyleView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var style = SubtitleStyle()
    var onStyleChanged: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                // Preview
                Section {
                    subtitlePreview
                } header: {
                    Text("Preview")
                }

                // Font
                Section {
                    Picker("Font", selection: $style.fontName) {
                        ForEach(SubtitleStyle.availableFonts, id: \.name) { font in
                            Text(font.displayName)
                                .tag(font.name)
                        }
                    }

                    // Font size stepper
                    HStack {
                        Text("Size")
                        Spacer()
                        Button(action: { if style.fontSize > 16 { style.fontSize -= 2 } }) {
                            Image(systemName: "minus.circle")
                        }
                        Text("\(Int(style.fontSize))pt")
                            .monospacedDigit()
                            .frame(minWidth: 50)
                        Button(action: { if style.fontSize < 72 { style.fontSize += 2 } }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                } header: {
                    Text("Font")
                }

                // Color
                Section {
                    Picker("Text Color", selection: $style.textColorHex) {
                        ForEach(SubtitleStyle.availableColors, id: \.hex) { color in
                            HStack {
                                Circle()
                                    .fill(Color(hex: color.hex))
                                    .frame(width: 20, height: 20)
                                Text(color.name)
                            }
                            .tag(color.hex)
                        }
                    }
                } header: {
                    Text("Color")
                }

                // Background & Outline
                Section {
                    Toggle("Text Background", isOn: $style.backgroundEnabled)

                    if style.backgroundEnabled {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Button(action: { if style.backgroundOpacity > 0.1 { style.backgroundOpacity -= 0.1 } }) {
                                Image(systemName: "minus.circle")
                            }
                            Text("\(Int(style.backgroundOpacity * 100))%")
                                .monospacedDigit()
                                .frame(minWidth: 50)
                            Button(action: { if style.backgroundOpacity < 1.0 { style.backgroundOpacity += 0.1 } }) {
                                Image(systemName: "plus.circle")
                            }
                        }
                    }

                    Toggle("Text Outline", isOn: $style.outlineEnabled)
                } header: {
                    Text("Background & Outline")
                }

                // Timing
                Section {
                    HStack {
                        Text("Subtitle Delay")
                        Spacer()
                        Button(action: { style.delayMs -= 250 }) {
                            Image(systemName: "minus.circle")
                        }
                        Text(delayText)
                            .monospacedDigit()
                            .frame(minWidth: 80)
                        Button(action: { style.delayMs += 250 }) {
                            Image(systemName: "plus.circle")
                        }
                    }

                    if style.delayMs != 0 {
                        Button("Reset Delay") {
                            style.delayMs = 0
                        }
                        .foregroundStyle(.red)
                    }
                } header: {
                    Text("Timing")
                } footer: {
                    Text("Adjust if subtitles appear too early (negative) or too late (positive). Steps of 250ms.")
                }

                // Reset
                Section {
                    Button("Reset to Defaults") {
                        style.fontSize = 42
                        style.fontName = "System"
                        style.textColorHex = "#FFFFFF"
                        style.backgroundEnabled = true
                        style.backgroundOpacity = 0.6
                        style.outlineEnabled = true
                        style.delayMs = 0
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Subtitle Appearance")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onStyleChanged?()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Preview

    private var subtitlePreview: some View {
        ZStack {
            // Dark video background simulation
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.black, .gray.opacity(0.3), .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack {
                Spacer()

                Text("This is how your subtitles will look.")
                    .font(.system(size: style.fontSize * 0.5)) // scaled for preview
                    .fontWeight(.medium)
                    .foregroundStyle(Color(hex: style.textColorHex))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        style.backgroundEnabled
                            ? RoundedRectangle(cornerRadius: 4)
                                .fill(.black.opacity(style.backgroundOpacity))
                            : nil
                    )
                    .overlay(
                        style.outlineEnabled
                            ? Text("This is how your subtitles will look.")
                                .font(.system(size: style.fontSize * 0.5))
                                .fontWeight(.medium)
                                .foregroundStyle(.clear)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            : nil
                    )

                Spacer().frame(height: 16)
            }
        }
    }

    // MARK: - Helpers

    private var delayText: String {
        if style.delayMs == 0 { return "0ms" }
        let sign = style.delayMs > 0 ? "+" : ""
        return "\(sign)\(style.delayMs)ms"
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }

        var rgb: UInt64 = 0xFFFFFF
        Scanner(string: cleaned).scanHexInt64(&rgb)

        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
