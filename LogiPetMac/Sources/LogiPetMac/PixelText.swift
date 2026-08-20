import AppKit
import CoreText
import SwiftUI

/// Draws the bundled pixel font without macOS font smoothing or subpixel positioning.
/// SwiftUI's Text always applies Core Text antialiasing, even when its surrounding
/// layer uses nearest-neighbour filtering, so the XP interface uses this view instead.
struct PixelText: NSViewRepresentable {
    let text: String
    var size: CGFloat = 9
    var color: NSColor = .labelColor
    var lineLimit: Int = 1
    var alignment: NSTextAlignment = .left
    var underline = false

    func makeNSView(context: Context) -> PixelTextView {
        let view = PixelTextView()
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateNSView(_ nsView: PixelTextView, context: Context) {
        nsView.configure(
            text: text,
            size: size,
            color: color,
            lineLimit: lineLimit,
            alignment: alignment,
            underline: underline
        )
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: PixelTextView,
        context: Context
    ) -> CGSize? {
        nsView.measure(maxWidth: proposal.width)
    }
}

final class PixelTextView: NSView {
    private var text = ""
    private var size: CGFloat = 9
    private var color: NSColor = .labelColor
    private var lineLimit = 1
    private var alignment: NSTextAlignment = .left
    private var underline = false
    private var cachedBitmap: CGImage?
    private var cachedBitmapSize = CGSize.zero

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { false }
    override var intrinsicContentSize: NSSize { measure(maxWidth: nil) }

    func configure(
        text: String,
        size: CGFloat,
        color: NSColor,
        lineLimit: Int,
        alignment: NSTextAlignment,
        underline: Bool
    ) {
        guard self.text != text || self.size != size || self.color != color ||
                self.lineLimit != lineLimit || self.alignment != alignment ||
                self.underline != underline else { return }

        self.text = text
        self.size = size
        self.color = color
        self.lineLimit = max(1, lineLimit)
        self.alignment = alignment
        self.underline = underline
        cachedBitmap = nil
        setAccessibilityLabel(text)
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    func measure(maxWidth: CGFloat?) -> CGSize {
        let attributed = attributedString()
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let naturalWidth = CGFloat(CTLineGetTypographicBounds(
            CTLineCreateWithAttributedString(attributed), nil, nil, nil
        ))
        let widthConstraint = maxWidth.map { max(1, $0) } ?? max(1, naturalWidth + 1)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(),
            nil,
            CGSize(width: widthConstraint, height: .greatestFiniteMagnitude),
            nil
        )
        let lineHeight = pixelLineHeight
        let measuredHeight = min(ceil(suggested.height), lineHeight * CGFloat(lineLimit))
        return CGSize(
            width: ceil(min(naturalWidth + 1, widthConstraint)),
            height: max(lineHeight, measuredHeight)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty, let context = NSGraphicsContext.current?.cgContext else { return }

        let logicalSize = CGSize(
            width: max(1, ceil(bounds.width)),
            height: max(1, ceil(bounds.height))
        )
        if cachedBitmap == nil || cachedBitmapSize != logicalSize {
            cachedBitmap = makeOneXBitmap(size: logicalSize)
            cachedBitmapSize = logicalSize
        }
        guard let bitmap = cachedBitmap else { return }

        context.saveGState()
        context.clip(to: bounds)
        context.interpolationQuality = .none
        context.setAllowsAntialiasing(false)
        context.setShouldAntialias(false)
        context.draw(bitmap, in: bounds)
        context.restoreGState()
    }

    override func setFrameSize(_ newSize: NSSize) {
        if frame.size != newSize {
            cachedBitmap = nil
        }
        super.setFrameSize(newSize)
    }

    /// Rasterize at one bitmap pixel per SwiftUI point. On a Retina display the
    /// resulting pixels are enlarged to 2×2 device pixels with nearest-neighbour
    /// sampling, rather than letting Core Text redraw the glyphs at Retina scale.
    private func makeOneXBitmap(size: CGSize) -> CGImage? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let bitmapContext = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
            return nil
        }

        bitmapContext.clear(CGRect(origin: .zero, size: size))
        bitmapContext.setAllowsAntialiasing(false)
        bitmapContext.setShouldAntialias(false)
        bitmapContext.setAllowsFontSmoothing(false)
        bitmapContext.setShouldSmoothFonts(false)
        bitmapContext.setShouldSubpixelPositionFonts(false)
        bitmapContext.setShouldSubpixelQuantizeFonts(true)

        if lineLimit == 1 {
            drawSingleLine(in: bitmapContext, bounds: CGRect(origin: .zero, size: size))
        } else {
            let path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString())
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(), path, nil)
            CTFrameDraw(frame, bitmapContext)
        }
        return bitmap.cgImage
    }

    private func drawSingleLine(in context: CGContext, bounds: CGRect) {
        let sourceLine = CTLineCreateWithAttributedString(attributedString())
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let naturalWidth = CGFloat(CTLineGetTypographicBounds(
            sourceLine, &ascent, &descent, &leading
        ))
        let availableWidth = max(1, bounds.width)
        let line: CTLine
        if naturalWidth > availableWidth {
            let token = CTLineCreateWithAttributedString(
                NSAttributedString(string: "…", attributes: attributes())
            )
            line = CTLineCreateTruncatedLine(sourceLine, Double(availableWidth), .end, token) ?? sourceLine
        } else {
            line = sourceLine
        }

        let renderedWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let x: CGFloat
        switch alignment {
        case .center:
            x = floor((bounds.width - renderedWidth) / 2)
        case .right:
            x = floor(bounds.width - renderedWidth)
        default:
            x = 0
        }
        let baseline = floor((bounds.height - (ascent + descent)) / 2 + descent)
        context.textPosition = CGPoint(x: max(0, x), y: max(descent, baseline))
        CTLineDraw(line, context)
    }

    private var pixelLineHeight: CGFloat {
        let font = pixelFont
        return ceil(font.ascender - font.descender + font.leading)
    }

    private var pixelFont: NSFont {
        NSFont(name: "Galmuri11", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    private func attributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineLimit == 1 ? .byTruncatingTail : .byWordWrapping
        var values: [NSAttributedString.Key: Any] = [
            .font: pixelFont,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        if underline {
            values[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return values
    }

    private func attributedString() -> NSAttributedString {
        NSAttributedString(string: text, attributes: attributes())
    }
}
