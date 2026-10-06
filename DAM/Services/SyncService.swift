import Foundation
import Observation

/// Free sync between your iPhone and Mac without a paid developer account:
/// pick the same iCloud Drive folder on both devices and DAM keeps a merged copy there.
@MainActor
@Observable
final class SyncService {
    static let fileName = "DAM-Sync.json"

    private(set) var folderName: String? = nil
    private(set) var lastSync: Date? = nil
    private(set) var lastError: String? = nil
    private(set) var syncing = false

    @ObservationIgnored private var pending: Task<Void, Never>? = nil

    func refresh(_ model: AppModel) {
        folderName = resolve(model)?.lastPathComponent
    }

    func connect(_ url: URL, model: AppModel) async {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            #if os(iOS)
            let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            #else
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            #endif
            model.updateSettings { $0.syncBookmark = bookmark }
            folderName = url.lastPathComponent
            lastError = nil
        } catch {
            lastError = "Couldn't remember that folder: \(error.localizedDescription)"
            return
        }
        await sync(model)
    }

    func disconnect(_ model: AppModel) {
        model.updateSettings { $0.syncBookmark = nil }
        folderName = nil
        lastSync = nil
        lastError = nil
    }

    /// Debounced sync after local saves.
    func scheduleSync(_ model: AppModel, delay: Double = 3) {
        guard model.settings.syncBookmark != nil else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.sync(model)
        }
    }

    func sync(_ model: AppModel) async {
        guard !syncing, let folder = resolve(model) else { return }
        syncing = true
        defer { syncing = false }
        let file = folder.appendingPathComponent(Self.fileName)

        let read = await Task.detached { SyncIO.read(folder: folder, file: file) }.value
        var remoteRaw: Data? = nil
        switch read {
        case .success(let data): remoteRaw = data
        case .failure(let error):
            lastError = "Couldn't read sync file: \(error.localizedDescription)"
            return
        }
        if let remoteRaw {
            do {
                let remote = try Store.decoder.decode(AppData.self, from: remoteRaw)
                model.absorb(remote)
            } catch {
                lastError = "The sync file is damaged or from a newer version."
                return
            }
        }
        guard let out = try? model.syncPayload() else { return }
        if out != remoteRaw {
            if let error = await Task.detached(operation: { SyncIO.write(out, folder: folder, file: file) }).value {
                lastError = "Couldn't write sync file: \(error.localizedDescription)"
                return
            }
        }
        lastSync = Date()
        lastError = nil
    }

    private func resolve(_ model: AppModel) -> URL? {
        guard let bookmark = model.settings.syncBookmark else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    }
}

/// File IO off the main thread, coordinated so iCloud Drive plays nicely.
enum SyncIO {
    static func read(folder: URL, file: URL) -> Result<Data?, Error> {
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        try? FileManager.default.startDownloadingUbiquitousItem(at: file)
        var coordinationError: NSError?
        var result: Result<Data?, Error> = .success(nil)
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &coordinationError) { url in
            if FileManager.default.fileExists(atPath: url.path) {
                do { result = .success(try Data(contentsOf: url)) } catch { result = .failure(error) }
            }
        }
        if let coordinationError, FileManager.default.fileExists(atPath: file.path) { return .failure(coordinationError) }
        return result
    }

    static func write(_ data: Data, folder: URL, file: URL) -> Error? {
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &coordinationError) { url in
            do { try data.write(to: url, options: .atomic) } catch { writeError = error }
        }
        return coordinationError ?? writeError
    }
}
