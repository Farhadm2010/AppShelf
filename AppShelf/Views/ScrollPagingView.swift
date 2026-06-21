import SwiftUI
import AppKit

// Lets mouse-wheel / trackpad horizontal scroll flip pages, the same way
// the old macOS Dock / Launchpad let you scroll instead of only clicking
// the page dots.
//
// This intentionally does NOT use NSViewRepresentable + scrollWheel(with:).
// That approach requires inserting a plain NSView into the SwiftUI
// hierarchy, and on macOS that view has to sit ABOVE the rest of the
// content in z-order for AppKit to route scrollWheel to it at all — but
// doing that silently breaks every onHover/onTapGesture/onDrag underneath
// it (the page dots, icon taps, icon dragging), because the new view
// claims hit-testing for the whole window.
//
// Instead this uses NSEvent.addLocalMonitorForEvents(matching: .scrollWheel),
// a window-level event tap: it observes scroll events as they pass through
// the app and returns them unmodified so they keep going to whatever
// SwiftUI/AppKit view would have received them anyway. No view inserted
// into the hit-testing chain, nothing else in the app can be affected.
struct ScrollPagingModifier: ViewModifier {
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void

    func body(content: Content) -> some View {
        content.background(
            ScrollMonitorInstaller(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight)
                .frame(width: 0, height: 0) // invisible, no layout impact, no hit-testing footprint
        )
    }
}

extension View {
    func pagingScroll(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) -> some View {
        modifier(ScrollPagingModifier(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight))
    }
}

// Tiny invisible NSViewRepresentable whose only job is to install/remove
// the local event monitor at the right time — it never itself receives
// or handles events, so it has no hit-testing or z-order implications.
private struct ScrollMonitorInstaller: NSViewRepresentable {
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSwipeLeft = onSwipeLeft
        context.coordinator.onSwipeRight = onSwipeRight
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var onSwipeLeft: () -> Void
        var onSwipeRight: () -> Void
        private var monitor: Any?

        // Accumulated delta for the gesture currently in progress.
        private var accumulated: CGFloat = 0

        // How far you need to scroll before it counts as "turn the page" —
        // tuned to feel like a single deliberate swipe, not a full drag.
        private let triggerThreshold: CGFloat = 60

        // Once a page-change fires, further deltas in the same gesture are
        // ignored until this cooldown elapses. This is what stops one
        // continuous swipe from flipping through multiple pages at once.
        private let cooldown: TimeInterval = 0.45
        private var lockedUntil: Date = .distantPast

        init(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) {
            self.onSwipeLeft = onSwipeLeft
            self.onSwipeRight = onSwipeRight
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event)
                return event // never swallow the event — everything downstream keeps working normally
            }
        }

        func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func handle(_ event: NSEvent) {
            #if DEBUG
            print("pagingScroll — dx:\(event.scrollingDeltaX) dy:\(event.scrollingDeltaY) phase:\(event.phase.rawValue)")
            #endif

            if event.phase == .began || event.momentumPhase == .began {
                accumulated = 0
            }

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY

            // Most plain scroll-wheel mice (anything without a tilt
            // wheel — including the Apple Magic Mouse) physically cannot
            // produce a horizontal delta; scrollingDeltaX is always ~0 for
            // them. Trackpads and tilt-wheel mice send real horizontal
            // deltas. Prefer horizontal input when present; otherwise
            // treat vertical wheel scroll as paging too, so an ordinary
            // mouse can still trigger this.
            let effectiveDelta: CGFloat
            if abs(dx) > 0.01 {
                guard abs(dx) > abs(dy) else { return } // predominantly vertical trackpad scroll — ignore
                effectiveDelta = dx
            } else {
                guard abs(dy) > 0.01 else { return }
                effectiveDelta = dy
            }

            let now = Date()
            if now < lockedUntil { return } // debounced — already paged for this gesture

            accumulated += effectiveDelta

            if accumulated <= -triggerThreshold {
                onSwipeLeft()
                lockedUntil = now.addingTimeInterval(cooldown)
                accumulated = 0
            } else if accumulated >= triggerThreshold {
                onSwipeRight()
                lockedUntil = now.addingTimeInterval(cooldown)
                accumulated = 0
            }

            if event.phase == .ended || event.phase == .cancelled {
                accumulated = 0
            }
        }
    }
}
