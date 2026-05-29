import SwiftUI
import AppKit

struct HoverDetector: NSViewRepresentable {
    var onHover: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = HoverNSView()
        view.onHover = onHover
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class HoverNSView: NSView {
    var onHover: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }
}
