import Foundation

/// Append-only text log next to the data store, so long-running jobs can be followed from outside the app.
enum AppLog {
    nonisolated static var url: URL {
        PersistenceController.storeURL.deletingLastPathComponent().appendingPathComponent("app.log")
    }

    nonisolated static func write(_ line: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let data = Data("\(stamp) \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}
