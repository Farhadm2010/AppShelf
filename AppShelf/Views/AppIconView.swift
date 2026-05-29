import SwiftUI

struct AppIconView: View {
    let app: MacApp
    let isDragging: Bool
    let isEditMode: Bool
    let isFolderTarget: Bool
    let onTap: () -> Void
    let onHide: () -> Void
    var onLongPress: (() -> Void)? = nil

    @State private var jiggleAngle: Double = 0
    @State private var jiggleTimer: Timer? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 11) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 88, height: 88)
                        .opacity(isDragging ? 0.25 : 1.0)
                        .scaleEffect(isFolderTarget ? 1.15 : 1.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(isFolderTarget ? 0.9 : 0), lineWidth: 3)
                                .scaleEffect(isFolderTarget ? 1.15 : 1.0)
                        )
                        .shadow(
                            color: isFolderTarget ? .white.opacity(0.4) : .clear,
                            radius: isFolderTarget ? 12 : 0
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFolderTarget)
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 88, height: 88)
                        .opacity(isDragging ? 0.25 : 1.0)
                        .scaleEffect(isFolderTarget ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFolderTarget)
                }

                Text(app.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(isDragging ? 0.25 : 1.0))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 110)
            }
            .frame(width: 132, height: 143)
            .scaleEffect(isDragging ? 1.08 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)

            if isEditMode {
                Button(action: onHide) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: -2, y: 2)
            }
        }
        .rotationEffect(.degrees(isEditMode ? jiggleAngle : 0))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.6) {
            onLongPress?()
        }
        .onAppear { if isEditMode { startJiggle() } }
        .onDisappear { stopJiggle() }
        .onChange(of: isEditMode) { _, newValue in
            if newValue { startJiggle() } else { stopJiggle() }
        }
    }

    func startJiggle() {
        jiggleTimer?.invalidate()
        var tick = 0
        jiggleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            tick += 1
            withAnimation(.easeInOut(duration: 0.1)) {
                jiggleAngle = tick % 2 == 0 ? 2.0 : -2.0
            }
        }
    }

    func stopJiggle() {
        jiggleTimer?.invalidate()
        jiggleTimer = nil
        withAnimation(.easeInOut(duration: 0.1)) { jiggleAngle = 0 }
    }
}
