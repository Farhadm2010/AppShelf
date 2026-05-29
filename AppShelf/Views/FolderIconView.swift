import SwiftUI

struct FolderIconView: View {
    let folder: AppFolder
    let isDragging: Bool
    let isEditMode: Bool
    let onTap: () -> Void
    let onHide: (MacApp) -> Void

    @State private var jiggleAngle: Double = 0
    @State private var jiggleTimer: Timer? = nil

    var previewApps: [MacApp] { Array(folder.apps.prefix(4)) }

    var body: some View {
        VStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 88, height: 88)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(34), spacing: 4), count: 2),
                    spacing: 4
                ) {
                    ForEach(previewApps) { app in
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 34, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 34, height: 34)
                        }
                    }
                }
                .padding(10)
            }
            .opacity(isDragging ? 0.3 : 1.0)

            Text(folder.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(isDragging ? 0.3 : 1.0))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 110)
        }
        .frame(width: 132, height: 143)
        .rotationEffect(.degrees(isEditMode ? jiggleAngle : 0))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
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
