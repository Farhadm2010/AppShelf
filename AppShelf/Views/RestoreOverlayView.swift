import SwiftUI

struct RestoreOverlayView: View {
    @ObservedObject var vm: AppShelfViewModel
    @Binding var isShowing: Bool

    let columns = Array(repeating: GridItem(.fixed(100), spacing: 20), count: 5)

    var hiddenApps: [MacApp] {
        vm.pages.flatMap { page in
            page.items.compactMap { item -> MacApp? in
                if case .app(let a) = item, a.isHidden { return a }
                return nil
            }
        }
    }

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
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hidden Apps")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Click any app to restore it")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowing = false
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 30, height: 30)
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 28)

                if hiddenApps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No hidden apps")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.vertical, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(hiddenApps) { app in
                            Button {
                                vm.restoreApp(app)
                                if hiddenApps.count <= 0 {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isShowing = false
                                    }
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        if let icon = app.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .interpolation(.high)
                                                .frame(width: 72, height: 72)
                                                .opacity(0.6)
                                        } else {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.1))
                                                .frame(width: 72, height: 72)
                                        }
                                        ZStack {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 22, height: 22)
                                            Image(systemName: "plus")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.black)
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                    Text(app.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 90)
                                }
                                .frame(width: 100, height: 115)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.1, green: 0.14, blue: 0.26).opacity(0.97))
                    .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 10)
            )
            .padding(.horizontal, 60)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}
