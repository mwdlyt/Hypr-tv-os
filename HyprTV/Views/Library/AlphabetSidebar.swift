import SwiftUI

/// Vertical A-Z alphabet sidebar for quick-jump navigation in library grids.
struct AlphabetSidebar: View {

    let onLetterSelected: (String) -> Void

    @FocusState private var focusedLetter: String?

    private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init) + ["#"]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(letters, id: \.self) { letter in
                Button {
                    onLetterSelected(letter)
                } label: {
                    Text(letter)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .frame(width: 30, height: 24)
                        .background(
                            focusedLetter == letter
                                ? AnyShapeStyle(.blue)
                                : AnyShapeStyle(.clear),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                }
                .buttonStyle(.plain)
                .focused($focusedLetter, equals: letter)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
