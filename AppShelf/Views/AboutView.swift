import SwiftUI

struct AboutView: View {
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowing = false
                    }
                }

            VStack(spacing: 0) {
                // App icon placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.4, blue: 0.9),
                                    Color(red: 0.1, green: 0.2, blue: 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 20)

                Text("AppShelf")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 6)

                Text("Version 1.0")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 24)

                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.bottom, 20)

                VStack(spacing: 8) {
                    Text("Your personal macOS app launcher")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Organize · Search · Launch")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 28)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowing = false
                    }
                } label: {
                    Text("Close")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.1, green: 0.14, blue: 0.26).opacity(0.97))
                    .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 10)
            )
            .padding(.horizontal, 400)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}
