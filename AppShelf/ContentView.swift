import SwiftUI

struct ContentView: View {
    @StateObject private var vm = AppShelfViewModel()
    @State private var showRestore = false
    @State private var showAbout = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.22),
                    Color(red: 0.05, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .onTapGesture {
                if vm.isEditMode { vm.toggleEditMode() }
            }

            VStack(spacing: 0) {
                Spacer(minLength: 20)
                    .frame(maxHeight: 40)

                if !vm.pages.isEmpty && vm.currentPageIndex < vm.pages.count {
                    AppGridView(
                        vm: vm,
                        pageIndex: vm.currentPageIndex,
                        onShowRestore: { showRestore = true }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    .id(vm.currentPageIndex)
                    .animation(.easeInOut(duration: 0.25), value: vm.currentPageIndex)
                } else if vm.pages.isEmpty {
                    Text("No apps found.")
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer(minLength: 0)

                PageDotsView(
                    vm: vm,
                    onDropToPage: { uuid, pageIndex in
                        vm.moveItemToPage(itemID: uuid, toPageIndex: pageIndex)
                    }
                )
            }
            .padding(.horizontal, 40)

            // Rescan button — bottom left
            VStack {
                Spacer()
                HStack {
                    Button {
                        vm.rescanAndMerge()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 20)
                    .padding(.bottom, 16)
                    Spacer()
                }
            }

            // About button — bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAbout = true
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
                }
            }

            if showRestore {
                RestoreOverlayView(vm: vm, isShowing: $showRestore)
                    .zIndex(20)
            }

            if showAbout {
                AboutView(isShowing: $showAbout)
                    .zIndex(20)
            }
        }
        .focusable()
        .onKeyPress(.leftArrow) {
            vm.cleanupOnPageChange()
            vm.previousPage()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            vm.cleanupOnPageChange()
            vm.nextPage()
            return .handled
        }
        .onLongPressGesture(minimumDuration: 0.8) {
            if !vm.isEditMode && vm.draggingAppID == nil {
                vm.toggleEditMode()
            }
        }
    }
}
