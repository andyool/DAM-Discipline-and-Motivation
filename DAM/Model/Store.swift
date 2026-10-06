import Foundation

/// Saves everything as one JSON file in Application Support, with a rolling week of daily backups.
final class Store {
    let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("DAM", isDirectory: true)
        }
    }

    var fileURL: URL { directory.appendingPathComponent("dam-save.json") }
    var backupDirectory: URL { directory.appendingPathComponent("Backups", isDirectory: true) }

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    static var decoder: JSONDecoder { JSONDecoder() }

    func load() -> AppData? {
        guard let raw = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try Store.decoder.decode(AppData.self, from: raw)
        } catch {
            print("DAM: could not decode save file: \(error)")
            // Keep the unreadable file around rather than overwriting it.
            let broken = directory.appendingPathComponent("dam-save-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: broken)
            return nil
        }
    }

    func save(_ data: AppData) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let raw = try Store.encoder.encode(data)
        try raw.write(to: fileURL, options: .atomic)
        try? backupIfNeeded(raw)
    }

    private func backupIfNeeded(_ raw: Data) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let today = backupDirectory.appendingPathComponent("dam-\(Day.today()).json")
        if !fm.fileExists(atPath: today.path) {
            try raw.write(to: today, options: .atomic)
        }
        let files = try fm.contentsOfDirectory(atPath: backupDirectory.path).filter { $0.hasPrefix("dam-") }.sorted()
        for name in files.dropLast(7) {
            try? fm.removeItem(at: backupDirectory.appendingPathComponent(name))
        }
    }
}
