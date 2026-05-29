import Foundation
import AppKit

// MARK: - MacApp

struct MacApp: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let url: URL
    var icon: NSImage?
    var isHidden: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, url, isHidden
    }

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        self.isHidden = false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(URL.self, forKey: .url)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        icon = NSWorkspace.shared.icon(forFile: url.path)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(isHidden, forKey: .isHidden)
    }
}

// MARK: - AppFolder

struct AppFolder: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var apps: [MacApp]

    init(name: String = "Folder", apps: [MacApp] = []) {
        self.id = UUID()
        self.name = name
        self.apps = apps
    }
}

// MARK: - PageItem (app or folder)

enum PageItem: Identifiable, Equatable, Codable {
    case app(MacApp)
    case folder(AppFolder)

    var id: UUID {
        switch self {
        case .app(let a): return a.id
        case .folder(let f): return f.id
        }
    }

    var isHidden: Bool {
        switch self {
        case .app(let a): return a.isHidden
        case .folder: return false
        }
    }

    var displayName: String {
        switch self {
        case .app(let a): return a.name
        case .folder(let f): return f.name
        }
    }
}

// MARK: - AppPage

struct AppPage: Identifiable, Codable {
    let id: UUID
    var title: String
    var items: [PageItem]

    init(title: String, items: [PageItem] = []) {
        self.id = UUID()
        self.title = title
        self.items = items
    }

    // Legacy migration: accept old "apps" key
    enum CodingKeys: String, CodingKey {
        case id, title, items, apps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        if let items = try? container.decode([PageItem].self, forKey: .items) {
            self.items = items
        } else if let apps = try? container.decode([MacApp].self, forKey: .apps) {
            self.items = apps.map { .app($0) }
        } else {
            self.items = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(items, forKey: .items)
    }

    var visibleItems: [PageItem] {
        items.filter { !$0.isHidden }
    }
}

// MARK: - LayoutFile

struct LayoutFile: Codable {
    var version: Int
    var pages: [AppPage]
}
