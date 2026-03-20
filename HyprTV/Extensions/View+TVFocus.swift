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
}
