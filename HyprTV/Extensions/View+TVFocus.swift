import SwiftUI

extension View {

    /// Applies the standard tvOS card interaction style to a view.
    func tvCardStyle() -> some View {
        self
            .focusable()
            .buttonStyle(.card)
    }

    /// Applies a scale-and-shadow effect that responds to focus state.
    /// Use with `@FocusState` or the `isFocused` environment value.
    @ViewBuilder
    func tvScaleEffect(isFocused: Bool) -> some View {
        self
            .scaleEffect(isFocused ? Constants.Animation.focusScaleFactor : 1.0)
            .animation(.easeInOut(duration: Constants.Animation.defaultDuration), value: isFocused)
            .shadow(
                color: .black.opacity(isFocused ? 0.3 : 0),
                radius: isFocused ? 20 : 0,
                y: isFocused ? 10 : 0
            )
    }

    /// Premium poster focus effect: scale up, white border glow, and shadow lift.
    /// Designed for portrait poster cards in content rows.
    @ViewBuilder
    func tvPosterEffect(isFocused: Bool) -> some View {
        self
            .scaleEffect(isFocused ? Constants.Animation.focusScaleFactor : 1.0)
            .shadow(
                color: .white.opacity(isFocused ? 0.25 : 0),
                radius: isFocused ? 12 : 0
            )
            .shadow(
                color: .black.opacity(isFocused ? 0.4 : 0),
                radius: isFocused ? 24 : 0,
                y: isFocused ? 12 : 0
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isFocused)
    }
}
