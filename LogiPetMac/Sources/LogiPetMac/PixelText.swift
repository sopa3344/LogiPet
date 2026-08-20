import AppKit
import SwiftUI

/// Readability-first pixel typography for the XP interface.
///
/// Galmuri11 is designed for a 9 pt / 12 px base size. SwiftUI is allowed to
/// render it at the display's native backing scale so Korean strokes retain
/// their detail on Retina screens. Nearest-neighbour filtering is reserved for
/// sprite images and is deliberately not applied to text.
struct PixelText: View {
    let text: String
    var size: CGFloat = 9
    var color: NSColor = .labelColor
    var lineLimit: Int = 1
    var alignment: NSTextAlignment = .left
    var underline = false

    var body: some View {
        Text(text)
            .font(.custom("Galmuri11", fixedSize: effectiveSize))
            .foregroundStyle(Color(nsColor: color))
            .lineLimit(max(1, lineLimit))
            .multilineTextAlignment(swiftUIAlignment)
            .underline(underline)
            .accessibilityLabel(Text(text))
    }

    private var effectiveSize: CGFloat {
        // Keep the tiny single-letter status icon compact, but never squeeze
        // Korean UI copy below Galmuri11's intended 9 pt base size.
        size == 7 ? 7 : max(9, size)
    }

    private var swiftUIAlignment: TextAlignment {
        switch alignment {
        case .center: .center
        case .right: .trailing
        default: .leading
        }
    }
}
