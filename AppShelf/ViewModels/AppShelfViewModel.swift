import Foundation
import AppKit
import Combine

class AppShelfViewModel: ObservableObject {
    @Published var pages: [AppPage] = []
    @Published var currentPageIndex: Int = 0
    @Published var draggingAppID: UUID? = nil
    @Published var isEditMode: Bool = false
    @Published var openFolderID: UUID? = nil

    // Which direction the page transition should animate: true when the
    // new page is to the right of the old one (slide in from the right),
    // false when it's to the left (slide in from the left). Updated by
    // every navigation method below — goToPage, nextPage, previousPage —
    // so scrolling, arrow keys, and clicking the page dots all animate
    // the correct direction instead of always sliding one way.
    @Published var navigatedForward: Bool = true

    let appsPerPage = 24

    private var nextPageNumber: Int = 1
    private var dragSafetyTimer: Timer?

    // Call when a drag is picked up (.onDrag). Arms a safety-net timeout so
    // that if the drop is released somewhere with no onDrop handler (missed
    // the folder target, dropped outside the window, etc.), draggingAppID
    // doesn't stay stuck forever — which otherwise silently blocks tap-to-launch
    // and re-entering edit mode with no visible error.
    func beginDrag(_ id: UUID) {
        draggingAppID = id
        dragSafetyTimer?.invalidate()
        dragSafetyTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.draggingAppID == id { self.draggingAppID = nil }
            }
        }
    }

    // Call on every successful or missed drop to clear drag state immediately.
    func endDrag() {
        dragSafetyTimer?.invalidate()
        dragSafetyTimer = nil
        draggingAppID = nil
    }

    // Real junk only: leftover installer/uninstaller relics and the app itself.
    // Built-in macOS Utilities (Terminal, Disk Utility, System Information, etc.)
    // must NOT be in this list — they're legitimate apps the old Deck/Launchpad
    // grouped into a single "Utilities" folder.
    private let systemJunk: Set<String> = [
        "idle", "logi options+ driver installer", "logipluginservice",
        "python launcher", "appshelf", "uninstall resolve",
        "fairlight studio utility", "davinci control panels setup",
        "davinci remote monitor", "blackmagic raw player",
        "blackmagic raw speed test", "blackmagic proxy generator",
        "samsungportablessd_1.0"
    ]

    private var saveURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("AppShelf")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("layout.json")
    }

    init() {
        if !loadLayout() {
            scanAndBuild()
        } else {
            removeEmptyPages()
        }
    }

    // MARK: - Page Number Tracking

    private func computeNextPageNumber() -> Int {
        let max = pages.compactMap { page -> Int? in
            let parts = page.title.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
            guard parts.count == 2, parts[0] == "Page", let n = Int(parts[1]) else { return nil }
            return n
        }.max() ?? 0
        return max + 1
    }

    private func freshPageTitle() -> String {
        let title = "Page \(nextPageNumber)"
        nextPageNumber += 1
        return title
    }

    private func renumberPages() {
        for i in pages.indices {
            pages[i].title = "Page \(i + 1)"
        }
        nextPageNumber = pages.count + 1
    }

    // MARK: - Scan & Build

    func scanAndBuild() {
        let rootPaths = [
            "/Applications",
            "/System/Applications",
            NSString("~/Applications").expandingTildeInPath
        ]

        var found: [MacApp] = []
        for path in rootPaths {
            let url = URL(fileURLWithPath: path)
            collectApps(in: url, into: &found, depth: 0)
        }

        var seen = Set<String>()
        let unique = found.filter { seen.insert($0.name.lowercased()).inserted }
        let filtered = unique.filter { !systemJunk.contains($0.name.lowercased()) }
        let sorted = filtered.sorted { $0.name.lowercased() < $1.name.lowercased() }

        let chunks = stride(from: 0, to: sorted.count, by: appsPerPage).map {
            Array(sorted[$0..<min($0 + appsPerPage, sorted.count)])
        }

        nextPageNumber = 1
        pages = chunks.enumerated().map { index, chunk in
            let title = "Page \(index + 1)"
            return AppPage(title: title, items: chunk.map { .app($0) })
        }
        nextPageNumber = pages.count + 1

        if pages.isEmpty {
            pages = [AppPage(title: "Page 1")]
            nextPageNumber = 2
        }

        saveLayout()
        removeEmptyPages()
    }

    private func collectApps(in url: URL, into found: inout [MacApp], depth: Int) {
        guard depth <= 1 else { return }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for item in contents {
            if item.pathExtension == "app" {
                found.append(MacApp(url: item))
            } else if depth < 1 {
                let values = try? item.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory == true {
                    collectApps(in: item, into: &found, depth: depth + 1)
                }
            }
        }
    }

    // MARK: - Persistence

    func saveLayout() {
        let layout = LayoutFile(version: 2, pages: pages)
        if let data = try? JSONEncoder().encode(layout) {
            try? data.write(to: saveURL)
        }
    }

    func loadLayout() -> Bool {
        guard let data = try? Data(contentsOf: saveURL),
              let layout = try? JSONDecoder().decode(LayoutFile.self, from: data),
              !layout.pages.isEmpty else {
            return false
        }
        pages = layout.pages
        renumberPages()
        return true
    }

    // MARK: - Navigation

    func launch(_ app: MacApp) {
        NSWorkspace.shared.openApplication(
            at: app.url,
            configuration: NSWorkspace.OpenConfiguration()
        )
        // Old Launchpad dismissed itself the moment you launched something —
        // hide AppShelf so it doesn't sit on screen over the app you opened.
        NSApp.hide(nil)
    }

    // navigatedForward must be committed to the view hierarchy BEFORE
    // currentPageIndex changes, or SwiftUI can briefly animate the
    // transition using the previous (now-stale) direction before
    // correcting itself — visible as a quick flash in the wrong direction.
    // Setting them in the same call on the same runloop tick isn't enough;
    // deferring the index change to the next tick gives SwiftUI a render
    // pass where only the direction changed, so by the time the index
    // changes the correct transition is already locked in.
    func goToPage(_ index: Int) {
        guard index >= 0, index < pages.count else { return }
        guard index != currentPageIndex else { return }
        navigatedForward = index >= currentPageIndex
        DispatchQueue.main.async { [weak self] in
            self?.currentPageIndex = index
        }
    }

    func nextPage() {
        guard currentPageIndex < pages.count - 1 else { return }
        navigatedForward = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.currentPageIndex < self.pages.count - 1 {
                self.currentPageIndex += 1
            }
        }
    }

    func previousPage() {
        guard currentPageIndex > 0 else { return }
        navigatedForward = false
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.currentPageIndex > 0 {
                self.currentPageIndex -= 1
            }
        }
    }

    func toggleEditMode() {
        isEditMode.toggle()
        if !isEditMode {
            openFolderID = nil
            removeEmptyPages()
        }
    }

    // MARK: - Page Management

    func addPage() {
        let title = freshPageTitle()
        pages.append(AppPage(title: title))
        currentPageIndex = pages.count - 1
        saveLayout()
    }

    func removeEmptyPages() {
        let nonEmpty = pages.filter { !$0.visibleItems.isEmpty }
        if nonEmpty.isEmpty { return }
        if nonEmpty.count == pages.count { return }
        let newIndex = min(currentPageIndex, nonEmpty.count - 1)
        pages = nonEmpty
        renumberPages()
        currentPageIndex = newIndex
        saveLayout()
    }

    func cleanupOnPageChange() {
        removeEmptyPages()
    }

    // MARK: - App Operations

    func hideApp(_ app: MacApp) {
        for pi in pages.indices {
            for ii in pages[pi].items.indices {
                if case .app(var a) = pages[pi].items[ii], a.id == app.id {
                    a.isHidden = true
                    pages[pi].items[ii] = .app(a)
                    removeEmptyPages()
                    return
                }
                if case .folder(var f) = pages[pi].items[ii] {
                    if let ai = f.apps.firstIndex(where: { $0.id == app.id }) {
                        f.apps.remove(at: ai)
                        if f.apps.isEmpty {
                            pages[pi].items.remove(at: ii)
                            openFolderID = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                self.isEditMode = false
                            }
                        } else if f.apps.count == 1 {
                            let remaining = f.apps[0]
                            pages[pi].items[ii] = .app(remaining)
                            openFolderID = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                self.isEditMode = false
                            }
                        } else {
                            pages[pi].items[ii] = .folder(f)
                        }
                        saveLayout()
                        return
                    }
                }
            }
        }
    }

    func restoreApp(_ app: MacApp) {
        for pi in pages.indices {
            for ii in pages[pi].items.indices {
                if case .app(var a) = pages[pi].items[ii], a.id == app.id {
                    a.isHidden = false
                    pages[pi].items[ii] = .app(a)
                    saveLayout()
                    return
                }
            }
        }
    }

    func swapItems(fromID: UUID, toIndex: Int, onPageIndex: Int) {
        guard onPageIndex < pages.count else { return }
        let visible = pages[onPageIndex].visibleItems
        guard toIndex >= 0, toIndex < visible.count else { return }
        guard let fromVisible = visible.firstIndex(where: { $0.id == fromID }) else { return }
        guard fromVisible != toIndex else { return }

        let fromID2 = visible[fromVisible].id
        let toID = visible[toIndex].id

        guard let realFrom = pages[onPageIndex].items.firstIndex(where: { $0.id == fromID2 }),
              let realTo = pages[onPageIndex].items.firstIndex(where: { $0.id == toID }) else { return }

        pages[onPageIndex].items.swapAt(realFrom, realTo)
    }

    func commitLayout() { saveLayout() }

    func moveItemToPage(itemID: UUID, toPageIndex: Int) {
        guard toPageIndex < pages.count else { return }
        guard toPageIndex != currentPageIndex else { return }

        var foundItem: PageItem?
        for pi in pages.indices {
            if let idx = pages[pi].items.firstIndex(where: { $0.id == itemID }) {
                foundItem = pages[pi].items.remove(at: idx)
                break
            }
        }

        if let item = foundItem {
            if pages[toPageIndex].visibleItems.count < appsPerPage {
                pages[toPageIndex].items.append(item)
            } else {
                pages[toPageIndex].items.insert(item, at: 0)
            }
        }

        endDrag()
        saveLayout()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.removeEmptyPages()
        }
    }

    // MARK: - Folder Operations

    func createFolder(appID1: UUID, appID2: UUID, onPageIndex: Int) {
        guard onPageIndex < pages.count else { return }

        var app1: MacApp?
        var app2: MacApp?
        var idx1: Int?
        var idx2: Int?

        for (i, item) in pages[onPageIndex].items.enumerated() {
            if case .app(let a) = item {
                if a.id == appID1 { app1 = a; idx1 = i }
                if a.id == appID2 { app2 = a; idx2 = i }
            }
        }

        guard let a1 = app1, let a2 = app2,
              let i1 = idx1, let i2 = idx2 else { return }

        let folder = AppFolder(name: "Folder", apps: [a1, a2])
        let insertAt = min(i1, i2)
        let removeFirst = max(i1, i2)
        let removeSecond = min(i1, i2)

        pages[onPageIndex].items.remove(at: removeFirst)
        pages[onPageIndex].items.remove(at: removeSecond)
        pages[onPageIndex].items.insert(.folder(folder), at: insertAt)

        saveLayout()
    }

    func addAppToFolder(appID: UUID, folderID: UUID, onPageIndex: Int) {
        var foundApp: MacApp?
        var appPageIndex: Int?
        var appItemIndex: Int?

        for pi in pages.indices {
            for ii in pages[pi].items.indices {
                if case .app(let a) = pages[pi].items[ii], a.id == appID {
                    foundApp = a
                    appPageIndex = pi
                    appItemIndex = ii
                    break
                }
            }
            if foundApp != nil { break }
        }

        guard let app = foundApp,
              let api = appPageIndex,
              let aii = appItemIndex else { return }

        pages[api].items.remove(at: aii)

        for pi in pages.indices {
            for ii in pages[pi].items.indices {
                if case .folder(var f) = pages[pi].items[ii], f.id == folderID {
                    f.apps.append(app)
                    pages[pi].items[ii] = .folder(f)
                    saveLayout()
                    removeEmptyPages()
                    return
                }
            }
        }
    }

    func renameFolder(folderID: UUID, newName: String) {
        for pi in pages.indices {
            for ii in pages[pi].items.indices {
                if case .folder(var f) = pages[pi].items[ii], f.id == folderID {
                    f.name = newName
                    pages[pi].items[ii] = .folder(f)
                    saveLayout()
                    return
                }
            }
        }
    }

    // MARK: - Rescan

    func rescanAndMerge() {
        let rootPaths = [
            "/Applications",
            "/System/Applications",
            NSString("~/Applications").expandingTildeInPath
        ]

        var found: [MacApp] = []
        for path in rootPaths {
            let url = URL(fileURLWithPath: path)
            collectApps(in: url, into: &found, depth: 0)
        }

        var seen = Set<String>()
        let unique = found.filter { seen.insert($0.name.lowercased()).inserted }
        let filtered = unique.filter { !systemJunk.contains($0.name.lowercased()) }

        var existingNames = Set<String>()
        for page in pages {
            for item in page.items {
                if case .app(let a) = item { existingNames.insert(a.name.lowercased()) }
                if case .folder(let f) = item { f.apps.forEach { existingNames.insert($0.name.lowercased()) } }
            }
        }

        let newApps = filtered.filter { !existingNames.contains($0.name.lowercased()) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }

        guard !newApps.isEmpty else { return }

        for app in newApps {
            if let lastIndex = pages.indices.last,
               pages[lastIndex].visibleItems.count < appsPerPage {
                pages[lastIndex].items.append(.app(app))
            } else {
                let title = freshPageTitle()
                var newPage = AppPage(title: title)
                newPage.items.append(.app(app))
                pages.append(newPage)
            }
        }

        saveLayout()
    }
}
