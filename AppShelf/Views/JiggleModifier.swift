import SwiftUI

struct JiggleModifier: ViewModifier {
    let isActive: Bool
    @State private var angle: Double = 0
    @State private var timer: Timer? = nil

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isActive ? angle : 0))
            .onAppear { if isActive { start() } }
            .onDisappear { stop() }
            .onChange(of: isActive) { _, v in
                if v { start() } else { stop() }
            }
    }

    func start() {
        timer?.invalidate()
        var tick = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            tick += 1
            withAnimation(.easeInOut(duration: 0.1)) {
                angle = tick % 2 == 0 ? 2.0 : -2.0
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeInOut(duration: 0.1)) { angle = 0 }
    }
}
