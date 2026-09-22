import Foundation
import SwiftData
import ASOCore

enum PersistenceController {
    static let schema = Schema([
        TrackedApp.self, TrackedMarket.self, TrackedKeyword.self, RankObservation.self, PopularityObservation.self,
        MetadataSnapshotRecord.self, MetadataDraftRecord.self, ChangeLogEntry.self, TrainingRow.self, IdeaCandidate.self, ReleaseMarker.self, RatingObservation.self, ReviewRecord.self, AdsKeywordStat.self, RevenueSnapshot.self,
    ])

    /// `~/Library/Application Support/ASO Workbench/` — data, keys, log, trained models and backups.
    /// Resolved once per launch. The app was called "ASO Studio" before 1.0.0; its folder is renamed in place the first
    /// time (a same-volume rename, nothing is copied), so data, keys and history carry over.
    nonisolated static let supportDirectory: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ASO Workbench", isDirectory: true)
        let legacy = base.appendingPathComponent(LegacyName.folder, isDirectory: true)
        if !fm.fileExists(atPath: dir.path), fm.fileExists(atPath: legacy.path) {
            if (try? fm.moveItem(at: legacy, to: dir)) == nil { return legacy }   // keep working from the old folder if the rename fails
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// `store.sqlite` in the support folder — a plain SQLite file the user can back up or inspect.
    nonisolated static var storeURL: URL { supportDirectory.appendingPathComponent("store.sqlite") }

    /// Settings saved under the old bundle identifier are copied once, so preferences survive the rename.
    static func migrateLegacyDefaults() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "migratedLegacyDefaults") else { return }
        d.set(true, forKey: "migratedLegacyDefaults")
        guard let old = UserDefaults.standard.persistentDomain(forName: LegacyName.bundleID) else { return }
        var copied = 0
        for (k, v) in old where d.object(forKey: k) == nil { d.set(v, forKey: k); copied += 1 }
        if copied > 0 { AppLog.write("[rename] copied \(copied) setting(s) from \(LegacyName.bundleID)") }
    }

    /// Names used before the app became ASO Workbench.
    nonisolated enum LegacyName {
        static let folder = "ASO" + " Studio"
        static let bundleID = "com.mustafakendiguzel." + "asostudio"
    }

    /// The first launch of a new version copies the data file to `Backups/` before SwiftData migrates it, so an update
    /// can always be rolled back by putting the old app and the backup back. Keeps the five newest backups.
    static func backupIfVersionChanged() {
        let d = UserDefaults.standard
        let current = AppInfo.version
        let last = d.string(forKey: "lastLaunchedVersion")
        d.set(current, forKey: "lastLaunchedVersion")
        guard let last, last != current, FileManager.default.fileExists(atPath: storeURL.path) else { return }
        let fm = FileManager.default
        let dir = storeURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacingOccurrences(of: ":", with: "")
        let folder = dir.appendingPathComponent("v\(last) \(stamp)", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: storeURL.path + suffix)
            if fm.fileExists(atPath: src.path) { try? fm.copyItem(at: src, to: folder.appendingPathComponent(src.lastPathComponent)) }
        }
        let all = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey])) ?? [])
            .sorted { ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) }
        for old in all.dropFirst(5) { try? fm.removeItem(at: old) }
        AppLog.write("[update] \(last) → \(current): data backed up to \(folder.lastPathComponent)")
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let config = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not open the data store at \(storeURL.path): \(error)")
        }
    }
}
