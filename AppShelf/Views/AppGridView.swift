import SwiftUI
import UniformTypeIdentifiers

struct AppGridView: View {
    @ObservedObject var vm: AppShelfViewModel
    let pageIndex: Int
    let onShowRestore: () -> Void

    @State private var isEditingTitle = false
    @State private var titleInput = ""
    @State private var searchText = ""
    @State private var folderTargetID: UUID? = nil
    @State private var folderReadyToCreate: Bool = false
    @State private var folderCheckTimer: Timer? = nil

    let columns = Array(repeating: GridItem(.fixed(132), spacing: 28), count: 6)

    // Safe accessor: during the page-removal transition animation, an outgoing
    // AppGridView instance can briefly hold a pageIndex that no longer exists
    // (e.g. you drag the last app off a page, the now-empty page gets removed,
    // and vm.pages shrinks while this view is still animating out). Falling
    // back to an empty placeholder instead of subscripting avoids a crash.
    var page: AppPage {
        guard vm.pages.indices.contains(pageIndex) else { return AppPage(title: "") }
        return vm.pages[pageIndex]
    }

    // Global search across all pages
    var globalSearchResults: [(item: PageItem, pageTitle: String)] {
        guard !searchText.isEmpty else { return [] }
        var results: [(PageItem, String)] = []
        for page in vm.pages {
            for item in page.visibleItems {
                if item.displayName.localizedCaseInsensitiveContains(searchText) {
                    results.append((item, page.title))
                }
            }
        }
        return results
    }

    var isSearching: Bool { !searchText.isEmpty }

    var visibleItems: [PageItem] {
        page.visibleItems
    }

    var body: some View {
        if !vm.pages.indices.contains(pageIndex) {
            // This page no longer exists (removed because it became empty);
            // render nothing rather than touching vm.pages[pageIndex].
            Color.clear
        } else {
        ZStack {
            VStack(spacing: 0) {

                // ── Page Title (hidden during search) ──
                if !isSearching {
                    Group {
                        if isEditingTitle {
                            TextField("Page name", text: $titleInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(width: 240)
                                .onSubmit {
                                    let t = titleInput.trimmingCharacters(in: .whitespaces)
                                    if !t.isEmpty, vm.pages.indices.contains(pageIndex) { vm.pages[pageIndex].title = t }
                                    isEditingTitle = false
                                    vm.saveLayout()
                                }
                                .onAppear { titleInput = page.title }
                        } else {
                            HStack(spacing: 6) {
                                Text(page.title)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                Image(systemName: "pencil")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                            .onTapGesture {
                                if !vm.isEditMode {
                                    titleInput = page.title
                                    isEditingTitle = true
                                }
                            }
                        }
                    }
                    .padding(.bottom, 12)
                } else {
                    // Search results header
                    HStack {
                        Text("\(globalSearchResults.count) result\(globalSearchResults.count == 1 ? "" : "s") across all pages")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    .frame(width: 500)
                    .padding(.bottom, 12)
                }

                // ── Search Bar + Gear / Edit hint ──
                ZStack {
                    if vm.isEditMode {
                        HStack {
                            Text("Drag app onto another to create folder · Tap × to remove · Tap outside to exit")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.45))
                            Spacer()
                        }
                        .frame(width: 500)
                    } else {
                        HStack(spacing: 20) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white.opacity(0.4))
                                    .font(.system(size: 15))
                                ZStack(alignment: .leading) {
                                    if searchText.isEmpty {
                                        Text("Search all apps…")
                                            .font(.system(size: 15))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                    TextField("", text: $searchText)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                        .accentColor(.white)
                                }
                                if !searchText.isEmpty {
                                    Button { searchText = "" } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white.opacity(0.4))
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .frame(width: 452)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.1)))

                            VStack(spacing: 2) {
                                Image(systemName: "gear")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 38, height: 38)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                                Text("Hidden Apps")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.35))
                                    .fixedSize()
                            }
                            .onTapGesture { onShowRestore() }
                        }
                        .frame(width: 510, alignment: .leading)
                    }
                }
                .frame(height: 52)
                .padding(.bottom, 24)

                // ── Grid ──
                if isSearching {
                    // Global search results
                    LazyVGrid(columns: columns, spacing: 28) {
                        ForEach(Array(globalSearchResults.enumerated()), id: \.element.item.id) { _, result in
                            searchResultView(item: result.item, pageTitle: result.pageTitle)
                        }
                    }
                } else {
                    // Normal page view
                    LazyVGrid(columns: columns, spacing: 28) {
                        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                            itemView(item: item, index: index)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            // ── Folder Overlay ──
            if let folderID = vm.openFolderID,
               let folder = findFolder(id: folderID) {
                FolderOverlayView(vm: vm, folder: folder)
                    .zIndex(10)
            }
        }
        }
    }

    // MARK: - Search result view

    @ViewBuilder
    func searchResultView(item: PageItem, pageTitle: String) -> some View {
        switch item {
        case .app(let app):
            VStack(spacing: 0) {
                AppIconView(
                    app: app,
                    isDragging: false,
                    isEditMode: false,
                    isFolderTarget: false,
                    onTap: { vm.launch(app) },
                    onHide: {},
                    onLongPress: nil
                )
                Text(pageTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.top, 2)
            }

        case .folder(let folder):
            VStack(spacing: 0) {
                FolderIconView(
                    folder: folder,
                    isDragging: false,
                    isEditMode: false,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.openFolderID = folder.id
                        }
                    },
                    onHide: { _ in }
                )
                Text(pageTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Normal item view

    @ViewBuilder
    func itemView(item: PageItem, index: Int) -> some View {
        switch item {
        case .app(let app):
            AppIconView(
                app: app,
                isDragging: vm.draggingAppID == app.id,
                isEditMode: vm.isEditMode,
                isFolderTarget: folderTargetID == app.id,
                onTap: {
                    if vm.isEditMode { vm.toggleEditMode(); return }
                    if vm.draggingAppID == nil { vm.launch(app) }
                },
                onHide: { vm.hideApp(app) },
                onLongPress: {
                    if !vm.isEditMode { vm.toggleEditMode() }
                }
            )
            .onDrag {
                vm.beginDrag(app.id)
                return NSItemProvider(object: app.id.uuidString as NSString)
            }
            .onDrop(
                of: [UTType.plainText],
                isTargeted: Binding(
                    get: { folderTargetID == app.id },
                    set: { isOver in
                        if isOver { startFolderHover(over: app.id) }
                    }
                )
            ) { providers in
                handleDrop(providers: providers, ontoItem: item, atIndex: index)
            }

        case .folder(let folder):
            FolderIconView(
                folder: folder,
                isDragging: vm.draggingAppID == folder.id,
                isEditMode: vm.isEditMode,
                onTap: {
                    if vm.isEditMode { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.openFolderID = vm.openFolderID == folder.id ? nil : folder.id
                    }
                },
                onHide: { _ in }
            )
            .onDrag {
                vm.beginDrag(folder.id)
                return NSItemProvider(object: folder.id.uuidString as NSString)
            }
            .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                handleDrop(providers: providers, ontoItem: item, atIndex: index)
            }
        }
    }

    // MARK: - Folder hover timer

    func startFolderHover(over targetID: UUID) {
        guard vm.isEditMode else { return }
        guard let dragging = vm.draggingAppID, dragging != targetID else { return }
        guard vm.pages.indices.contains(pageIndex) else { return }
        let draggingIsApp = vm.pages[pageIndex].items.contains(where: {
            if case .app(let a) = $0 { return a.id == dragging }
            return false
        })
        guard draggingIsApp else { return }
        guard folderTargetID != targetID else { return }

        folderTargetID = targetID
        folderReadyToCreate = false
        folderCheckTimer?.invalidate()
        folderCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
            DispatchQueue.main.async {
                guard self.folderTargetID == targetID else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    self.folderReadyToCreate = true
                }
            }
        }
    }

    func cancelFolderHover() {
        folderCheckTimer?.invalidate()
        folderCheckTimer = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.15)) {
                self.folderTargetID = nil
                self.folderReadyToCreate = false
            }
        }
    }

    // MARK: - Drop handler

    func handleDrop(providers: [NSItemProvider], ontoItem: PageItem, atIndex: Int) -> Bool {
        let wasReady = folderReadyToCreate
        let capturedTarget = folderTargetID

        guard let provider = providers.first else {
            // No payload at all — still clear drag state so we don't get stuck.
            vm.endDrag()
            cancelFolderHover()
            return false
        }

        provider.loadObject(ofClass: NSString.self) { nsItem, _ in
            guard let str = nsItem as? String,
                  let uuid = UUID(uuidString: str) else {
                // Payload didn't parse — same deal, don't leave draggingAppID stuck.
                DispatchQueue.main.async {
                    vm.endDrag()
                    cancelFolderHover()
                }
                return
            }

            DispatchQueue.main.async {
                if case .folder(let f) = ontoItem {
                    vm.addAppToFolder(appID: uuid, folderID: f.id, onPageIndex: pageIndex)
                    vm.endDrag()
                    cancelFolderHover()
                    return
                }

                if vm.isEditMode,
                   wasReady,
                   case .app(let targetApp) = ontoItem,
                   uuid != targetApp.id,
                   capturedTarget == targetApp.id,
                   vm.pages.indices.contains(pageIndex) {
                    let draggingIsApp = vm.pages[pageIndex].items.contains(where: {
                        if case .app(let a) = $0 { return a.id == uuid }
                        return false
                    })
                    if draggingIsApp {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            vm.createFolder(appID1: uuid, appID2: targetApp.id, onPageIndex: pageIndex)
                        }
                        vm.endDrag()
                        cancelFolderHover()
                        return
                    }
                }

                if !wasReady {
                    vm.swapItems(fromID: uuid, toIndex: atIndex, onPageIndex: pageIndex)
                    vm.commitLayout()
                }
                vm.endDrag()
                cancelFolderHover()
            }
        }
        return true
    }

    // MARK: - Helper

    func findFolder(id: UUID) -> AppFolder? {
        for page in vm.pages {
            for item in page.items {
                if case .folder(let f) = item, f.id == id { return f }
            }
        }
        return nil
    }
}
