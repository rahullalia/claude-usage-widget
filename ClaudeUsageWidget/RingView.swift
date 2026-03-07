import AppKit

// MARK: - RingView

/// An NSView subclass that draws a circular progress ring using Core Graphics.
/// Primary use is as an image generator for the NSStatusItem button image.
class RingView: NSView {

    var progress: Double = 0.0 {
        didSet { needsDisplay = true }
    }

    var colorState: RingColorState = .normal {
        didSet { needsDisplay = true }
    }

    // MARK: - Image Generator

    /// Renders the ring to an NSImage for use as a status item button image.
    static func image(
        progress: Double,
        colorState: RingColorState,
        size: CGSize = CGSize(width: 18, height: 18)
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        drawRing(progress: progress, colorState: colorState, in: CGRect(origin: .zero, size: size))
        image.unlockFocus()
        image.isTemplate = (colorState == .normal)
        return image
    }

    // MARK: - NSView Drawing

    override func draw(_ dirtyRect: NSRect) {
        RingView.drawRing(progress: progress, colorState: colorState, in: bounds)
    }

    // MARK: - Core Drawing

    private static func drawRing(
        progress: Double,
        colorState: RingColorState,
        in rect: CGRect
    ) {
        let clampedProgress = min(max(progress, 0.0), 1.0)
        let ringColor = color(for: colorState)

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let trackLineWidth: CGFloat = 2.5
        let arcLineWidth: CGFloat = 3.0
        let radius = (min(rect.width, rect.height) / 2) - (arcLineWidth / 2)

        // Draw track: full circle at 20% opacity
        let track = NSBezierPath()
        track.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - 360,
            clockwise: true
        )
        track.lineWidth = trackLineWidth
        track.lineCapStyle = .round
        ringColor.withAlphaComponent(0.2).setStroke()
        track.stroke()

        // Draw progress arc (clockwise from top)
        // NSBezierPath angles: 0° = right, 90° = top, counter-clockwise positive
        // To go clockwise from top: startAngle=90, endAngle=90-(progress*360), clockwise=true
        guard clampedProgress > 0.0 else { return }

        let endAngle = 90.0 - (clampedProgress * 360.0)
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: endAngle,
            clockwise: true
        )
        arc.lineWidth = arcLineWidth
        arc.lineCapStyle = .round
        ringColor.setStroke()
        arc.stroke()
    }

    // MARK: - Color Mapping

    private static func color(for state: RingColorState) -> NSColor {
        switch state {
        case .normal:
            return .labelColor
        case .amber:
            return NSColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1)
        case .critical:
            return NSColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1)
        }
    }
}
