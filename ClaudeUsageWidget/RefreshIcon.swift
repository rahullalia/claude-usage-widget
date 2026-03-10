import AppKit

/// A button-like NSView that draws the teenyicons refresh icon via NSBezierPath.
/// Strokes with secondaryLabelColor so it adapts to light/dark mode automatically.
class RefreshButton: NSView {

    var onRefresh: (() -> Void)?
    var isEnabled: Bool = true {
        didSet { alphaValue = isEnabled ? 1.0 : 0.3; needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 16, height: 16)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupTracking()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTracking()
    }

    private func setupTracking() {
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        onRefresh?()
    }

    override func resetCursorRects() {
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // The teenyicons refresh icon is designed for a 15x15 viewBox.
        // Scale to fit the view bounds.
        let viewBox: CGFloat = 15.0
        let scaleX = bounds.width / viewBox
        let scaleY = bounds.height / viewBox

        ctx.saveGState()
        ctx.scaleBy(x: scaleX, y: scaleY)
        // Flip Y — NSView coords are bottom-up, SVG coords are top-down
        ctx.translateBy(x: 0, y: viewBox)
        ctx.scaleBy(x: 1, y: -1)

        let path = CGMutablePath()

        // Arc 1: M7.5 14.5 C3.634 14.5 0.5 11.366 0.5 7.5 C0.5 5.269 1.544 3.282 3.169 2
        path.move(to: CGPoint(x: 7.5, y: 14.5))
        path.addCurve(to: CGPoint(x: 0.5, y: 7.5),
                      control1: CGPoint(x: 3.634, y: 14.5),
                      control2: CGPoint(x: 0.5, y: 11.366))
        path.addCurve(to: CGPoint(x: 3.1694, y: 2.0),
                      control1: CGPoint(x: 0.5, y: 5.269),
                      control2: CGPoint(x: 1.544, y: 3.282))

        // Arc 2: M7.5 0.5 C11.366 0.5 14.5 3.634 14.5 7.5 C14.5 9.731 13.456 11.718 11.831 13
        path.move(to: CGPoint(x: 7.5, y: 0.5))
        path.addCurve(to: CGPoint(x: 14.5, y: 7.5),
                      control1: CGPoint(x: 11.366, y: 0.5),
                      control2: CGPoint(x: 14.5, y: 3.634))
        path.addCurve(to: CGPoint(x: 11.8306, y: 13.0),
                      control1: CGPoint(x: 14.5, y: 9.731),
                      control2: CGPoint(x: 13.456, y: 11.718))

        // Arrow 1: M11.5 10 V13.5 H15
        path.move(to: CGPoint(x: 11.5, y: 10.0))
        path.addLine(to: CGPoint(x: 11.5, y: 13.5))
        path.addLine(to: CGPoint(x: 15.0, y: 13.5))

        // Arrow 2: M0 1.5 H3.5 V5
        path.move(to: CGPoint(x: 0.0, y: 1.5))
        path.addLine(to: CGPoint(x: 3.5, y: 1.5))
        path.addLine(to: CGPoint(x: 3.5, y: 5.0))

        ctx.addPath(path)
        ctx.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
        ctx.setLineWidth(1.0)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()

        ctx.restoreGState()
    }
}
