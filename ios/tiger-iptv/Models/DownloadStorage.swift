import Foundation
import CryptoKit

/// İndirilen medya dosyaları için cihaz üzerinde path yönetir.
/// Application Support/Downloads altında tutulur — Caches gibi iOS tarafından silinmez,
/// iCloud backup dışına alınır (medya dosyaları büyük).
enum DownloadStorage {
    /// Downloads kök dizini. Uygulama güncellemelerinde korunur.
    static func rootDirectory() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = appSupport.appendingPathComponent("Downloads", isDirectory: true)
        if !fm.fileExists(atPath: root.path) {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            try markExcludedFromBackup(root)
        }
        return root
    }

    /// Belirli bir item için hedef relative path döner (DB'de saklanır).
    /// Biçim: `<playlistId>/<type>/<streamId>.<ext>`
    static func relativePath(playlistId: UUID, type: String, streamId: String, ext: String) -> String {
        let safeExt = ext.isEmpty ? "mp4" : ext
        let safeStream = streamId.replacingOccurrences(of: "/", with: "_")
        return "\(playlistId.uuidString)/\(type)/\(safeStream).\(safeExt)"
    }

    /// DB'deki `localPath`'i absolute URL'e çevirir.
    static func absoluteURL(forRelativePath relativePath: String) throws -> URL {
        try rootDirectory().appendingPathComponent(relativePath)
    }

    /// Hedef dosyanın parent klasörünü oluşturur.
    static func ensureParentDirectory(for relativePath: String) throws -> URL {
        let fullURL = try absoluteURL(forRelativePath: relativePath)
        let parent = fullURL.deletingLastPathComponent()
        let fm = FileManager.default
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        return fullURL
    }

    /// Bir dosyayı iCloud backup dışında tutar.
    private static func markExcludedFromBackup(_ url: URL) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutable = url
        try mutable.setResourceValues(resourceValues)
    }

    /// Playlist silinince tüm dosyalarını diskten siler.
    static func removePlaylistDirectory(playlistId: UUID) {
        guard let root = try? rootDirectory() else { return }
        let dir = root.appendingPathComponent(playlistId.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    /// Tek bir dosyayı siler.
    static func removeFile(relativePath: String) {
        guard let url = try? absoluteURL(forRelativePath: relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Pending (kurtarma) dosyaları

    /// Delegate, indirmenin hangi satıra ait olduğunu henüz bilmiyorsa (uygulama
    /// arka planda uyandırıldığında DB geri yüklemesi bitmeden `didFinishDownloadingTo`
    /// çağrılabilir) dosyayı burada geçici olarak tutarız. Sonra `restoreOutstandingTasks`
    /// remoteURL eşleşmesiyle dosyayı yerine taşır. Böylece %100 inmiş bir dosya
    /// çöpe gitmez ve sıfırdan tekrar indirilmez.
    static func pendingDirectory() throws -> URL {
        let root = try rootDirectory()
        let dir = root.appendingPathComponent("_pending", isDirectory: true)
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try? markExcludedFromBackup(dir)
        }
        return dir
    }

    /// Uzak URL'den kararlı (launch'lar arası sabit) bir anahtar üretir.
    static func pendingKey(forRemoteURL remoteURL: String) -> String {
        let digest = SHA256.hash(data: Data(remoteURL.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// İndirilen geçici dosyayı kurtarma klasörüne taşır. Başarılıysa true.
    @discardableResult
    static func storePendingFile(from location: URL, remoteURL: String) -> Bool {
        guard let dir = try? pendingDirectory() else { return false }
        let dest = dir.appendingPathComponent(pendingKey(forRemoteURL: remoteURL) + ".bin")
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
            try fm.moveItem(at: location, to: dest)
            return true
        } catch {
            return false
        }
    }

    /// Kurtarma klasöründe bu URL'ye ait dosya varsa hedef relative path'e taşır
    /// ve boyutunu döner. Yoksa nil.
    static func takePendingFile(forRemoteURL remoteURL: String, to relativePath: String) -> Int64? {
        guard let dir = try? pendingDirectory() else { return nil }
        let source = dir.appendingPathComponent(pendingKey(forRemoteURL: remoteURL) + ".bin")
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { return nil }
        do {
            let destination = try ensureParentDirectory(for: relativePath)
            if fm.fileExists(atPath: destination.path) { try? fm.removeItem(at: destination) }
            try fm.moveItem(at: source, to: destination)
            let attrs = try? fm.attributesOfItem(atPath: destination.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            return size > 0 ? size : nil
        } catch {
            return nil
        }
    }

    /// Belirli bir URL'ye ait bekleyen kurtarma dosyasını siler.
    static func removePendingFile(forRemoteURL remoteURL: String) {
        guard let dir = try? pendingDirectory() else { return }
        let target = dir.appendingPathComponent(pendingKey(forRemoteURL: remoteURL) + ".bin")
        try? FileManager.default.removeItem(at: target)
    }

    /// Kurtarma klasörünü temizler.
    static func clearPendingFiles() {
        guard let dir = try? pendingDirectory() else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Storage stats

    /// Belirtilen klasör altındaki tüm dosyaların toplam bayt boyutunu döner.
    /// Klasör yoksa 0.
    private static func usedBytes(at directory: URL) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path),
              let enumerator = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              )
        else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               values.isRegularFile == true,
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    /// Tüm indirilmiş/kısmi medya dosyalarının toplam bayt boyutu.
    static func totalUsedBytes() -> Int64 {
        guard let root = try? rootDirectory() else { return 0 }
        return usedBytes(at: root)
    }

    /// Belirli bir playlist'e ait dosyaların toplam bayt boyutu.
    static func usedBytes(playlistId: UUID) -> Int64 {
        guard let root = try? rootDirectory() else { return 0 }
        let dir = root.appendingPathComponent(playlistId.uuidString, isDirectory: true)
        return usedBytes(at: dir)
    }
}
