import SwiftUI
import UniformTypeIdentifiers

struct FolderOverlayView: View {
    @ObservedObject var vm: AppShelfViewModel
    let folder: AppFolder

    @State private var isEditingName = false
    @State private var nameInput = ""

    let columns = Array(repeating: GridItem(.fixed(100), spacing: 20), count: 4)

    var body: some View {
        ZStack {
            // Dimmed background — click to close, also acts as drop zone to pull app out
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.openFolderID = nil
                    }
                }
                // Drop onto background = remove from folder, add to current page
                .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                    guard let provider = providers.first else {
                        vm.endDrag()
                        return false
                    }
                    provider.loadObject(ofClass: NSString.self) { item, _ in
                        DispatchQueue.main.async {
                            if let str = item as? String,
                               let uuid = UUID(uuidString: str) {
                                pullAppOutOfFolder(appID: uuid)
                            }
                            // Always clear, whether the drop matched or not —
                            // otherwise a missed drop leaves draggingAppID stuck
                            // and the app silently stops responding to taps/long-press.
                            vm.endDrag()
                        }
                    }
                    return true
                }

            // Folder panel
            VStack(spacing: 0) {

                // Folder name
                Group {
                    if isEditingName {
                        TextField("Folder name", text: $nameInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(width: 220)
                            .onSubmit {
                                let t = nameInput.trimmingCharacters(in: .whitespaces)
                                if !t.isEmpty {
                                    vm.renameFolder(folderID: folder.id, newName: t)
                                }
                                isEditingName = false
                            }
                            .onAppear { nameInput = folder.name }
                    } else {
                        HStack(spacing: 6) {
                            Text(folder.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .onTapGesture {
                            nameInput = folder.name
                            isEditingName = true
                        }
                    }
                }
                .padding(.bottom, 8)

                // Hint text
                Text("Drag app outside panel to remove from folder")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 20)

                // Apps grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(folder.apps) { app in
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 8) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 72, height: 72)
                                } else {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 72, height: 72)
                                }
                                Text(app.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 90)
                            }
                            .frame(width: 100, height: 110)
                            .onTapGesture {
                                if vm.isEditMode { return }
                                vm.launch(app)
                                vm.openFolderID = nil
                            }
                            // Drag to pull out of folder
                            .onDrag {
                                vm.beginDrag(app.id)
                                return NSItemProvider(object: app.id.uuidString as NSString)
                            }

                            if vm.isEditMode {
                                Button {
                                    vm.hideApp(app)
                                    if folder.apps.count <= 1 {
                                        vm.openFolderID = nil
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 20, height: 20)
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                                .buttonStyle(.plain)
                                .offset(x: 2, y: -2)
                            }
                        }
                        .modifier(JiggleModifier(isActive: vm.isEditMode))
                    }
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.1, green: 0.14, blue: 0.26).opacity(0.96))
                    .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 10)
            )
            .padding(.horizontal, 220)
            // Panel itself is NOT a drop zone — dropping outside panel = pull out
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: - Pull app out of folder onto current page

    func pullAppOutOfFolder(appID: UUID) {
        guard let pageIndex = vm.pages.indices.first(where: { pi in
            vm.pages[pi].items.contains(where: {
                if case .folder(let f) = $0 { return f.id == folder.id }
                return false
            })
        }) else { return }

        // Find folder
        for ii in vm.pages[pageIndex].items.indices {
            if case .folder(var f) = vm.pages[pageIndex].items[ii], f.id == folder.id {
                guard let ai = f.apps.firstIndex(where: { $0.id == appID }) else { return }
                let app = f.apps.remove(at: ai)

                if f.apps.isEmpty {
                    // Folder now empty — remove it
                    vm.pages[pageIndex].items.remove(at: ii)
                    vm.openFolderID = nil
                } else if f.apps.count == 1 {
                    // Only 1 app left — dissolve folder
                    let remaining = f.apps[0]
                    vm.pages[pageIndex].items[ii] = .app(remaining)
                    vm.openFolderID = nil
                } else {
                    vm.pages[pageIndex].items[ii] = .folder(f)
                }

                // Add pulled app to page
                vm.pages[pageIndex].items.append(.app(app))
                vm.saveLayout()
                return
            }
        }
    }
}
