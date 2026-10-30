import Foundation
import GRDB
import Combine
import os.log
#if canImport(UserNotifications)
import UserNotifications
#endif

private let downloadLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "Downloads")

/// taskIdentifier → indirme satırı eşlemesi (delegate kuyruğundan senkron okunur).
private struct DownloadTaskMeta: Sendable {
    let id: String
    let relPath: String
}

/// İlerleme yayın aralığı (saniye). 0.2 sn ≈ saniyede 5 güncelleme — akıcı ve hafif.
/// Global sabit: delegate kuyruğundan (main dışı) güvenle okunur.
private let downloadProgressPublishInterval: TimeInterval = 0.2
/// task.taskDescription içinde id ile relPath'i ayıran karakter (U+001F).
private let downloadTaskSeparator = "\u{001F}"

/// İndirme ilerlemesinin bellek içi temsili — UI sıkça değiştiği için DB'ye yazmayız.
struct DownloadProgress: Equatable {
    let totalBytes: Int64
    let downloadedBytes: Int64
    /// Anlık hız (bayt/saniye). 0 ise bilinmiyor.
    var bytesPerSecond: Double = 0
    /// Sunucu `Content-Length` göndermediyse (Xtream/M3U akışlarında çok yaygın)
    /// `totalBytes == 0` olur. Bu durumda yüzde hesaplanamaz — UI ilerlemeyi
    /// indirilen boyut üzerinden göstermeli, aksi halde sonsuza dek %0 görünür.
    var hasKnownTotal: Bool { totalBytes > 0 }
    var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1.0, Double(downloadedBytes) / Double(totalBytes))
    }
}

/// Paralel kuyruk: her playlist için aynı anda `maxConcurrentPerPlaylist` (3–4)
/// indirme çalışır, gerisi `.queued` DB status'üyle bekler. `createdAt`'a göre
/// sıralanır; biri bitince bir sonraki otomatik başlar. Uygulama yeniden açıldığında
/// yarım kalan indirmeler kuyruğa geri alınıp devam ettirilir. Ayrıca bir watchdog,
/// veri akışı 45 sn boyunca durursa task'i otomatik yeniden başlatır.
///
/// Background indirme için `URLSessionConfiguration.background` kullanır; OS uygulamayı
/// sonlandırsa bile iOS indirmeyi sürdürür ve bitince app'i uyandırarak delegate'i çağırır.
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    static let sessionIdentifier = (Bundle.main.bundleIdentifier ?? "app") + ".downloads"
    /// Aynı playlist için aynı anda kaç indirme paralel çalışabilir. Üstü kuyruğa alınır.
    /// Başka playlist'lerin kuyruğu etkilenmez — her playlist'in kendi slotu vardır.
    ///
    /// ÖNEMLİ: Eskiden 1 idi ve indirmeler tek tek (seri) iniyordu; bölüm/film
    /// listesi indirirken bu "çok yavaş" hissi veriyordu. Artık paralel indirme
    /// açık (varsayılan 3, `f125` toplu indirme açıksa 4).
    static var maxConcurrentPerPlaylist: Int {
        TigerFeatureRuntime.shared.isOn("f125") ? 4 : 3
    }
    /// Bir indirme hata alınca kaç kez otomatik kuyruğun sonuna geri eklenir. Aşılınca `.failed`.
    private static let maxAutoRetries = 3

    /// Aktif indirmelerin ilerlemesi, view'ların gözlemlemesi için.
    @Published private(set) var progress: [String: DownloadProgress] = [:]
    /// DB yazmalarından sonra artan counter — GRDBQuery dışındaki view'ların refresh tetiği.
    @Published private(set) var dbVersion: Int = 0

    private var session: URLSession!
    /// URLSessionTask.taskIdentifier → downloadedItem.id haritası.
    private var taskToId: [Int: String] = [:]
    /// downloadedItem.id → URLSessionDownloadTask (iptal için).
    private var idToTask: [String: URLSessionDownloadTask] = [:]
    /// downloadedItem.id → playlistId; per-playlist slot sayımı için.
    private var idToPlaylistId: [String: UUID] = [:]
    /// URLSessionTask.taskIdentifier → hedef relative path (delegate'de DB lookup yapmamak için).
    private var taskToRelativePath: [Int: String] = [:]
    /// `enqueue` async DB write yaparken — aynı id'ye ikinci çağrı gelmesin diye in-memory guard.
    private var enqueueInFlight: Set<String> = []
    /// Aynı task için didWriteData defalarca tetiklenir; totalBytes'i sadece ilk gerçek değerde DB'ye yazıyoruz.
    private var totalBytesPersistedFor: Set<Int> = []
    /// didWriteData saniyede yüzlerce kez tetiklenir. Her seferinde `@Published progress`
    /// güncellemek main thread'i dolduruyor ve indirme hızını düşürüyordu. Bu yüzden
    /// ilerleme yayınını throttle ediyoruz (durum: `Self.throttleState`, kilitli).
    /// Hata alan indirmelerin bellek içi yeniden-deneme sayacı.
    private var autoRetryCountById: [String: Int] = [:]
    /// Hata sonrası URLSession'ın verdiği resume data — yeniden başlatırken
    /// sıfırdan indirmek yerine kaldığı yerden devam etmek için.
    private var resumeDataById: [String: Data] = [:]
    /// `pumpQueue` aynı anda bir kere çalışsın diye — paralel çağrılar `pumpPending`'ı set eder.
    private var pumpInFlight = false
    /// Pump çalışırken başka bir pump tetiklendiyse, mevcut pump bitmeden önce bir kez daha döner.
    private var pumpPending = false
    /// AppDelegate'in verdiği background completion handler; `urlSessionDidFinishEvents` çağırınca tetiklenir.
    var backgroundCompletionHandler: (() -> Void)?

    /// URLSession delegate çağrıları için ayrı seri kuyruk.
    /// `.main` kullanmak UI çizimiyle yarışıyor ve indirmeyi yavaşlatıyordu.
    private static let delegateQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.tigeriptv.downloads.delegate"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .utility
        return q
    }()

    /// Delegate kuyruğundan (main dışı) erişilen throttle durumu — kilit ile korunur.
    private nonisolated(unsafe) static let throttleLock = NSLock()
    private nonisolated(unsafe) static var throttleState: [Int: (bytes: Int64, at: TimeInterval)] = [:]

    /// taskIdentifier → (id, relPath). Delegate kuyruğu main dışında çalıştığı için
    /// bu eşleme kilitli static bir sözlükte tutulur; böylece `didFinishDownloadingTo`
    /// MainActor'a hiç dokunmadan (ve uygulama yeniden açıldığında `taskDescription`
    /// kaybolsa bile) doğru satırı bulur.
    nonisolated(unsafe) private static let metaLock = NSLock()
    nonisolated(unsafe) private static var metaByTask: [Int: DownloadTaskMeta] = [:]

    nonisolated private static func setMeta(_ meta: DownloadTaskMeta, for taskId: Int) {
        metaLock.lock(); metaByTask[taskId] = meta; metaLock.unlock()
    }
    nonisolated private static func meta(for taskId: Int) -> DownloadTaskMeta? {
        metaLock.lock(); defer { metaLock.unlock() }; return metaByTask[taskId]
    }
    nonisolated private static func clearMeta(for taskId: Int) {
        metaLock.lock(); metaByTask.removeValue(forKey: taskId); metaLock.unlock()
    }
    /// taskDescription'dan okumayı dener, olmazsa kilitli sözlükten okur.
    nonisolated private static func resolveMeta(for task: URLSessionTask) -> DownloadTaskMeta? {
        if let m = meta(for: task.taskIdentifier) { return m }
        if let parsed = parseTaskDescription(task.taskDescription) {
            let m = DownloadTaskMeta(id: parsed.id, relPath: parsed.relPath)
            setMeta(m, for: task.taskIdentifier)
            return m
        }
        return nil
    }

    /// Bekleme (stall) denetleyicisi: ilerleme durursa task'i otomatik yeniden başlatır.
    private var watchdogTask: Task<Void, Never>?
    /// taskIdentifier → son görülen bayt sayısı (watchdog için).
    private var lastSeenBytes: [Int: Int64] = [:]
    /// taskIdentifier → son ilerleme zamanı (watchdog için).
    private var lastSeenAt: [Int: Date] = [:]
    /// taskIdentifier → kaç kez yeniden başlatıldı.
    private var stallRestarts: [Int: Int] = [:]
    /// İlerleme bu süre boyunca hiç değişmezse task yeniden başlatılır.
    private static let stallTimeout: TimeInterval = 45
    /// Watchdog kontrol aralığı.
    private static let watchdogInterval: TimeInterval = 10
    /// Bir task en fazla kaç kez stall nedeniyle yeniden başlatılır.
    private static let maxStallRestarts = 3

    /// task.taskDescription içinde id ile relPath'i ayıran karakter (U+001F).
    /// Delegate kuyruğundan (main dışı) senkron okunabilmesi için id + relPath'i
    /// tek bir string'e paketler.
    nonisolated private static func taskDescription(id: String, relPath: String) -> String {
        id + downloadTaskSeparator + relPath
    }

    /// `taskDescription`'ı (id, relPath) olarak çözer.
    nonisolated private static func parseTaskDescription(_ raw: String?) -> (id: String, relPath: String)? {
        guard let raw else { return nil }
        let parts = raw.split(separator: "\u{001F}", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let id = String(parts[0])
        let relPath = String(parts[1])
        guard !id.isEmpty, !relPath.isEmpty else { return nil }
        return (id, relPath)
    }

    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        // Paralel bağlantı sayısını yükselt — tek bağlantıya sıkışmayı engeller.
        config.httpMaximumConnectionsPerHost = 8
        config.httpShouldUsePipelining = true
        // Ağ yoksa bekle (hata verip kuyruğu bozmasın).
        config.waitsForConnectivity = true
        // Low Data Mode / pahalı ağ kısıtlamaları indirmeyi yavaşlatıyordu — izin ver.
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 60 * 24
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: Self.delegateQueue)
        Task { await restoreOutstandingTasks() }
        startWatchdog()
    }

    // MARK: - Stall watchdog

    /// İndirme sessizce takılırsa (sunucu bağlantıyı askıya aldı, CDN yönlendirmesi
    /// yarıda kaldı vb.) hiçbir delegate çağrısı gelmez ve ilerleme donar.
    /// Bu denetleyici ilerlemeyi izler ve gerekirse task'i yeniden başlatır.
    private func startWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.watchdogInterval * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                await self.checkForStalls()
            }
        }
    }

    private func checkForStalls() async {
        guard !idToTask.isEmpty else { return }
        let now = Date()
        for (id, task) in idToTask {
            let taskId = task.taskIdentifier
            let received = task.countOfBytesReceived
            let previous = lastSeenBytes[taskId]

            if previous == nil {
                lastSeenBytes[taskId] = received
                lastSeenAt[taskId] = now
                continue
            }

            if received != previous {
                // İlerleme var — sayaçları tazele.
                lastSeenBytes[taskId] = received
                lastSeenAt[taskId] = now
                stallRestarts[taskId] = 0
                continue
            }

            let idleFor = now.timeIntervalSince(lastSeenAt[taskId] ?? now)
            guard idleFor >= Self.stallTimeout else { continue }

            let restarts = (stallRestarts[taskId] ?? 0) + 1
            stallRestarts[taskId] = restarts
            downloadLog.error("stall id=\(id, privacy: .public) idle=\(Int(idleFor), privacy: .public)s restart=\(restarts)")

            if restarts > Self.maxStallRestarts {
                // Israr eden takılma: hata olarak işaretle, kuyruk devam etsin.
                idToTask.removeValue(forKey: id)
                idToPlaylistId.removeValue(forKey: id)
                taskToId.removeValue(forKey: taskId)
                taskToRelativePath.removeValue(forKey: taskId)
                lastSeenBytes.removeValue(forKey: taskId)
                lastSeenAt.removeValue(forKey: taskId)
                stallRestarts.removeValue(forKey: taskId)
                task.cancel()
                await markFailed(
                    id: id,
                    error: NSError(domain: "Download", code: -4,
                                   userInfo: [NSLocalizedDescriptionKey: "Download stalled (no data received)"])
                )
                await pumpQueue()
                continue
            }

            // Yeniden başlat: resume verisi varsa onunla, yoksa baştan.
            let relPath = taskToRelativePath[taskId]
            let playlistId = idToPlaylistId[id]
            let remote = task.originalRequest?.url
            idToTask.removeValue(forKey: id)
            idToPlaylistId.removeValue(forKey: id)
            taskToId.removeValue(forKey: taskId)
            taskToRelativePath.removeValue(forKey: taskId)
            lastSeenBytes.removeValue(forKey: taskId)
            lastSeenAt.removeValue(forKey: taskId)
            task.cancel()

            guard let relPath, let playlistId, let remote else { continue }
            startTask(id: id, playlistId: playlistId, remoteURL: remote, relPath: relPath)
            dbVersion &+= 1
        }
    }

    // MARK: - App lifecycle

    /// App açıldığında: background session'da hâlâ canlı task varsa eşleştir, yoksa DB'de
    /// "downloading" olarak kalmış kayıtları tekrar `.queued`'e çevir (createdAt korunur →
    /// kuyruk sırası kaybolmaz). Sonra kuyruğu çalıştır.
    private func restoreOutstandingTasks() async {
        let downloadingRows: [DBDownloadedItem] = (try? await AppDatabase.shared.read { db in
            try DBDownloadedItem
                .filter(Column("status") == DownloadStatus.downloading.rawValue)
                .fetchAll(db)
        }) ?? []

        var matchedIds: Set<String> = []
        if !downloadingRows.isEmpty {
            let tasks = await session.allTasks
            for task in tasks {
                guard let url = task.originalRequest?.url?.absoluteString,
                      let match = downloadingRows.first(where: { $0.remoteURL == url }),
                      let downloadTask = task as? URLSessionDownloadTask else {
                    continue
                }
                taskToId[downloadTask.taskIdentifier] = match.id
                taskToRelativePath[downloadTask.taskIdentifier] = match.localPath
                downloadTask.taskDescription = Self.taskDescription(id: match.id, relPath: match.localPath)
                Self.setMeta(DownloadTaskMeta(id: match.id, relPath: match.localPath), for: downloadTask.taskIdentifier)
                idToTask[match.id] = downloadTask
                idToPlaylistId[match.id] = match.playlistId
                progress[match.id] = DownloadProgress(
                    totalBytes: Int64(match.totalBytes),
                    downloadedBytes: Int64(match.downloadedBytes)
                )
                matchedIds.insert(match.id)
            }
        }

        // Force-kill / OS-terminate sonrası iOS background task'i de düşürmüş olabilir.
        // DB "downloading" diyor ama session'da karşılık yok → kuyruğa geri al, sırayla devam etsin.
        // createdAt DEĞİŞTİRİLMEZ ki kullanıcının orjinal sırası korunsun.
        let orphans = downloadingRows.filter { !matchedIds.contains($0.id) }
        if !orphans.isEmpty {
            // Dosya diskte zaten tam inmiş olabilir (uygulama tam %100'de
            // kapatıldıysa). Öyleyse yeniden indirmek yerine tamamlandı say.
            var recovered: Set<String> = []
            var toQueue: [String] = []
            for orphan in orphans {
                // 1) Kurtarma klasöründe bu URL'ye ait tam inmiş dosya var mı?
                //    (uygulama %100'de kapatıldı / arka planda uyandırıldı)
                let pendingSize = DownloadStorage.takePendingFile(
                    forRemoteURL: orphan.remoteURL,
                    to: orphan.localPath
                )
                // 2) Yoksa hedef dosya diskte dolu mu?
                let size: Int64 = pendingSize ?? {
                    guard let url = try? DownloadStorage.absoluteURL(forRelativePath: orphan.localPath),
                          let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                          let s = attrs[.size] as? Int64 else { return 0 }
                    return s
                }()
                if size > 0 {
                    recovered.insert(orphan.id)
                    downloadLog.info("restore recovered id=\(orphan.id, privacy: .public) size=\(size, privacy: .public) — dosya zaten tam")
                } else {
                    toQueue.append(orphan.id)
                }
            }
            _ = try? await AppDatabase.shared.write { db in
                for orphan in orphans {
                    if var row = try DBDownloadedItem.filter(Column("id") == orphan.id).fetchOne(db) {
                        if recovered.contains(orphan.id) {
                            let size: Int64 = {
                                guard let url = try? DownloadStorage.absoluteURL(forRelativePath: row.localPath),
                                      let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                                      let s = attrs[.size] as? Int64 else { return 0 }
                                return s
                            }()
                            row.status = DownloadStatus.completed.rawValue
                            row.completedAt = Date()
                            row.totalBytes = Int(size)
                            row.downloadedBytes = Int(size)
                            row.errorMessage = nil
                        } else {
                            row.status = DownloadStatus.queued.rawValue
                            row.errorMessage = nil
                        }
                        try row.update(db)
                    }
                }
            }
            for id in toQueue {
                downloadLog.info("restore orphan id=\(id, privacy: .public) — DB downloading, task yok; kuyruğa geri alındı")
            }
            dbVersion &+= 1
        }

        await pumpQueue()
    }

    // MARK: - Public API

    /// İndirmeyi kuyruğa ekler. Kuyruk boşsa hemen başlar, değilse `.queued` olarak bekler.
    /// Aynı `id` zaten indiriliyor/kuyrukta ise çağrı yok sayılır.
    func enqueue(
        id: String,
        playlistId: UUID,
        streamId: String,
        type: String,
        title: String,
        secondaryTitle: String?,
        imageURL: String?,
        remoteURL: URL,
        containerExtension: String?,
        seriesId: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil
    ) async {
        if idToTask[id] != nil || enqueueInFlight.contains(id) { return }
        enqueueInFlight.insert(id)
        defer { enqueueInFlight.remove(id) }
        autoRetryCountById.removeValue(forKey: id)
        resumeDataById.removeValue(forKey: id)

        let ext = containerExtension ?? "mp4"
        let relPath = DownloadStorage.relativePath(playlistId: playlistId, type: type, streamId: streamId, ext: ext)
        // Yeniden indirmede eski/yarım dosya kalmasın — aksi halde "zaten indi"
        // sanılıp hatalı tamamlanabilir.
        DownloadStorage.removeFile(relativePath: relPath)

        // حدّ التخزين (f130): يمنع بدء تنزيل جديد عند تجاوز السقف المحدد.
        if TigerFeatureRuntime.shared.isOn("f130") {
            let policy = TigerFeatureRuntime.shared.downloadPolicy
            if policy.storageLimitGB > 0 {
                let usedBytes = await Self.totalDownloadedBytes()
                let limitBytes = Int64(policy.storageLimitGB * 1_073_741_824.0)
                if usedBytes >= limitBytes {
                    await persistFailed(
                        id: id, playlistId: playlistId, streamId: streamId, type: type,
                        title: title, secondaryTitle: secondaryTitle, imageURL: imageURL,
                        remoteURL: remoteURL.absoluteString, relPath: relPath,
                        containerExtension: containerExtension, seriesId: seriesId,
                        seasonNumber: seasonNumber, episodeNumber: episodeNumber,
                        errorMessage: "Storage limit reached"
                    )
                    return
                }
            }
        }

        do {
            _ = try DownloadStorage.ensureParentDirectory(for: relPath)
        } catch {
            await persistFailed(
                id: id, playlistId: playlistId, streamId: streamId, type: type,
                title: title, secondaryTitle: secondaryTitle, imageURL: imageURL,
                remoteURL: remoteURL.absoluteString, relPath: relPath,
                containerExtension: containerExtension, seriesId: seriesId,
                seasonNumber: seasonNumber, episodeNumber: episodeNumber,
                errorMessage: error.localizedDescription
            )
            return
        }

        // Her indirmeyi önce `.queued` olarak yaz; pump hemen sonra kuyruğu çalıştırır.
        // Bu sayede slot atama tek bir yerde (pumpQueue) olur, yarış durumu olmaz.
        do {
            try await AppDatabase.shared.write { db in
                var item = DBDownloadedItem(
                    id: id,
                    playlistId: playlistId,
                    streamId: streamId,
                    type: type,
                    title: title,
                    secondaryTitle: secondaryTitle,
                    imageURL: imageURL,
                    remoteURL: remoteURL.absoluteString,
                    localPath: relPath,
                    containerExtension: containerExtension,
                    totalBytes: 0,
                    downloadedBytes: 0,
                    status: DownloadStatus.queued.rawValue,
                    errorMessage: nil,
                    createdAt: Date(),
                    completedAt: nil,
                    seriesId: seriesId,
                    seasonNumber: seasonNumber,
                    episodeNumber: episodeNumber
                )
                try item.save(db)
            }
        } catch {
            return
        }
        dbVersion &+= 1
        downloadLog.info("enqueue id=\(id, privacy: .public) — kuyruğa alındı")
        await pumpQueue()
    }

    /// Devam eden veya kuyruktaki bir indirmeyi iptal eder; kısmi dosyayı ve DB row'unu siler.
    /// Aktif task iptal edildiyse kuyruktan sıradaki başlar.
    func cancel(id: String) {
        let hadActiveTask = idToTask[id] != nil
        if let task = idToTask[id] {
            task.cancel()
            idToTask.removeValue(forKey: id)
            taskToId.removeValue(forKey: task.taskIdentifier)
        }
        idToPlaylistId.removeValue(forKey: id)
        progress.removeValue(forKey: id)
        autoRetryCountById.removeValue(forKey: id)
        resumeDataById.removeValue(forKey: id)
        Task { [id] in
            await self.deleteRow(id: id, removeFile: true)
            if hadActiveTask { await self.pumpQueue() }
        }
    }

    /// Tamamlanmış/başarısız/kuyruktaki bir kaydı ve dosyasını siler.
    func delete(id: String) async {
        let hadActiveTask = idToTask[id] != nil
        if let task = idToTask[id] {
            task.cancel()
            idToTask.removeValue(forKey: id)
            taskToId.removeValue(forKey: task.taskIdentifier)
        }
        idToPlaylistId.removeValue(forKey: id)
        progress.removeValue(forKey: id)
        autoRetryCountById.removeValue(forKey: id)
        resumeDataById.removeValue(forKey: id)
        await deleteRow(id: id, removeFile: true)
        if hadActiveTask { await pumpQueue() }
    }

    /// Bir playlist silindiğinde çağrılır: ilgili task'leri iptal eder ve klasörü siler.
    func cleanupPlaylist(playlistId: UUID) {
        // Aktif task'ler: idToPlaylistId'den playlist eşleşmesiyle bul. `idToTask.keys`'i
        // string parse ile süzmek yerine playlist map'i daha güvenilir.
        let idsToCancel = idToPlaylistId.filter { $0.value == playlistId }.map(\.key)
        var hadAny = false
        for id in idsToCancel {
            if let task = idToTask[id] {
                task.cancel()
                taskToId.removeValue(forKey: task.taskIdentifier)
                hadAny = true
            }
            idToTask.removeValue(forKey: id)
            idToPlaylistId.removeValue(forKey: id)
            progress.removeValue(forKey: id)
            autoRetryCountById.removeValue(forKey: id)
            resumeDataById.removeValue(forKey: id)
        }
        DownloadStorage.removePlaylistDirectory(playlistId: playlistId)
        dbVersion &+= 1
        if hadAny { Task { await pumpQueue() } }
    }

    /// Tamamlanmış bir indirmenin local file URL'i (oynatma için).
    func localURL(forId id: String) async -> URL? {
        do {
            let row: DBDownloadedItem? = try await AppDatabase.shared.read { db in
                try DBDownloadedItem.filter(Column("id") == id).fetchOne(db)
            }
            guard let row, row.downloadStatus == .completed else { return nil }
            let url = try DownloadStorage.absoluteURL(forRelativePath: row.localPath)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        } catch {
            return nil
        }
    }

    /// Sadece belirli bir playlist'e ait tüm indirmeleri (her statüde) siler.
    /// Aktif task'leri iptal eder, dosyaları diskten kaldırır, DB row'larını siler.
    func deleteAll(playlistId: UUID) async {
        // Aktif task'ler
        let activeIds = idToPlaylistId.filter { $0.value == playlistId }.map(\.key)
        var hadAny = false
        for id in activeIds {
            if let task = idToTask[id] {
                task.cancel()
                taskToId.removeValue(forKey: task.taskIdentifier)
                hadAny = true
            }
            idToTask.removeValue(forKey: id)
            idToPlaylistId.removeValue(forKey: id)
            progress.removeValue(forKey: id)
            autoRetryCountById.removeValue(forKey: id)
            resumeDataById.removeValue(forKey: id)
        }
        // DB row'ları (bu playlist'e ait olanlar) ve dosyalar
        let rows: [DBDownloadedItem] = (try? await AppDatabase.shared.read { db in
            try DBDownloadedItem.filter(Column("playlistId") == playlistId).fetchAll(db)
        }) ?? []
        for row in rows {
            DownloadStorage.removeFile(relativePath: row.localPath)
            DownloadStorage.removePendingFile(forRemoteURL: row.remoteURL)
        }
        // Playlist klasörünü tamamen kaldır (subdir + olası boş klasörler).
        DownloadStorage.removePlaylistDirectory(playlistId: playlistId)
        _ = try? await AppDatabase.shared.write { db in
            try DBDownloadedItem.filter(Column("playlistId") == playlistId).deleteAll(db)
        }
        dbVersion &+= 1
        if hadAny { await pumpQueue() }
    }

    /// Tüm playlist'lerin indirmelerini (her statüde) siler.
    func deleteAll() async {
        for (id, task) in idToTask {
            task.cancel()
            taskToId.removeValue(forKey: task.taskIdentifier)
            progress.removeValue(forKey: id)
        }
        idToTask.removeAll()
        idToPlaylistId.removeAll()
        autoRetryCountById.removeAll()
        resumeDataById.removeAll()

        let all: [DBDownloadedItem] = (try? await AppDatabase.shared.read { db in
            try DBDownloadedItem.fetchAll(db)
        }) ?? []
        for row in all {
            DownloadStorage.removeFile(relativePath: row.localPath)
        }
        // Kurtarma klasöründe bekleyen dosyalar da temizlenir.
        DownloadStorage.clearPendingFiles()
        _ = try? await AppDatabase.shared.write { db in
            try DBDownloadedItem.deleteAll(db)
        }
        dbVersion &+= 1
    }

    // MARK: - ID helpers
    static func idFor(vod playlistId: UUID, streamId: Int) -> String {
        "vod.\(playlistId.uuidString).\(streamId)"
    }
    static func idFor(episode playlistId: UUID, episodeId: String) -> String {
        "episode.\(playlistId.uuidString).\(episodeId)"
    }
    /// M3U channel id'si UUID ile karışmasın diye `m3u_` prefix'i kullanırız.
    static func idFor(m3uChannel playlistId: UUID, channelId: String) -> String {
        "vod.\(playlistId.uuidString).m3u_\(channelId)"
    }

    // MARK: - Settings
    /// احترامًا لمزايا 200 (f121): يُقرأ الإعداد القديم أولًا، ثم سياسة المحرّك.
    private static var wifiOnly: Bool {
        if let legacy = UserDefaults.standard.object(forKey: "download.wifi_only") as? Bool {
            return legacy
        }
        return TigerFeatureRuntime.shared.downloadPolicy.wifiOnly
    }

    /// مجموع بايتات التنزيلات المكتملة — يُستخدم لحدّ التخزين (f130).
    private static func totalDownloadedBytes() async -> Int64 {
        (try? await AppDatabase.shared.read { db in
            try DBDownloadedItem
                .filter(Column("status") == DownloadStatus.completed.rawValue)
                .fetchAll(db)
                .reduce(Int64(0)) { $0 + Int64(max($1.totalBytes, 0)) }
        }) ?? 0
    }

    // MARK: - Queue pump

    /// Playlist için aktif (indiriliyor) download sayısı.
    private func activeDownloadCount(for playlistId: UUID) -> Int {
        idToPlaylistId.values.reduce(into: 0) { $0 += ($1 == playlistId ? 1 : 0) }
    }

    /// Verilen playlist için aktif bir indirme var mı — player warning'i için.
    func hasActiveDownload(playlistId: UUID) -> Bool {
        activeDownloadCount(for: playlistId) > 0
    }

    /// Kuyruğu işler: her playlist için `maxConcurrentPerPlaylist` kadar aktif task'e
    /// kadar `.queued` row'ları `.downloading`'e çeker. createdAt artan sırayla bakılır —
    /// playlist'inde slot varsa başlat, yoksa atla ve sonraki row'a bak.
    /// Aynı anda yalnızca bir pump çalışır; çakışan çağrılar `pumpPending` ile işaretlenir.
    private func pumpQueue() async {
        if pumpInFlight {
            pumpPending = true
            return
        }
        pumpInFlight = true
        defer { pumpInFlight = false }

        repeat {
            pumpPending = false

            let queuedRows: [DBDownloadedItem] = (try? await AppDatabase.shared.read { db in
                try DBDownloadedItem
                    .filter(Column("status") == DownloadStatus.queued.rawValue)
                    .order(Column("createdAt"))
                    .fetchAll(db)
            }) ?? []

            var remaining = queuedRows
            while !remaining.isEmpty {
                // İlk playlist'inde boş slot olan row'u al.
                guard let idx = remaining.firstIndex(where: { row in
                    activeDownloadCount(for: row.playlistId) < Self.maxConcurrentPerPlaylist
                }) else { break }
                let next = remaining.remove(at: idx)

                guard let url = URL(string: next.remoteURL) else {
                    downloadLog.error("pumpQueue id=\(next.id, privacy: .public) — URL bozuk, failed işaretleniyor")
                    await markFailed(
                        id: next.id,
                        error: NSError(domain: "Download", code: -3,
                                       userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
                    )
                    continue
                }

                // GÜVENLİK AĞI 1: kurtarma klasöründe bu URL'ye ait tam inmiş
                // dosya varsa yerine taşı, yeniden indirme.
                if let recoveredSize = DownloadStorage.takePendingFile(
                    forRemoteURL: next.remoteURL,
                    to: next.localPath
                ) {
                    downloadLog.info("pumpQueue id=\(next.id, privacy: .public) — kurtarma dosyası bulundu (\(recoveredSize) bayt)")
                    await markCompleted(id: next.id, fallbackSize: recoveredSize)
                    continue
                }

                // GÜVENLİK AĞI 2: dosya diskte zaten tam ise (satır yanlışlıkla
                // kuyruğa düştüyse) yeniden indirme — doğrudan tamamlandı say.
                // Aksi hâlde "%100 oldu, baştan indiriyor" durumu yaşanır.
                if let size = Self.existingFileSize(relativePath: next.localPath), size > 0 {
                    downloadLog.info("pumpQueue id=\(next.id, privacy: .public) — dosya zaten tam (\(size) bayt), yeniden indirilmiyor")
                    await markCompleted(id: next.id, fallbackSize: size)
                    continue
                }

                _ = try? await AppDatabase.shared.write { db in
                    if var row = try DBDownloadedItem.filter(Column("id") == next.id).fetchOne(db) {
                        row.status = DownloadStatus.downloading.rawValue
                        try row.update(db)
                    }
                }
                startTask(id: next.id, playlistId: next.playlistId, remoteURL: url, relPath: next.localPath)
                dbVersion &+= 1
            }
        } while pumpPending
    }

    /// DB row'u zaten var kabul edilir. URLSession task'ini kurar ve bellek içi haritalara yazar.
    private func startTask(id: String, playlistId: UUID, remoteURL: URL, relPath: String) {
        downloadLog.info("start id=\(id, privacy: .public) playlist=\(playlistId.uuidString, privacy: .public) url=\(remoteURL.absoluteString, privacy: .public)")
        let task: URLSessionDownloadTask
        // Yarım kalan bir indirme varsa resume data ile devam et — sıfırdan indirme.
        if let resumeData = resumeDataById[id] {
            task = session.downloadTask(withResumeData: resumeData)
            downloadLog.info("resume id=\(id, privacy: .public) — kaldığı yerden devam")
        } else {
            var request = URLRequest(url: remoteURL)
            request.allowsCellularAccess = !Self.wifiOnly
            task = session.downloadTask(with: request)
        }
        // Delegate kuyruğu main dışında çalıştığı için id + relPath'i task'ın
        // kendisine ve kilitli sözlüğe yazıyoruz; delegate senkron okuyabilir.
        task.taskDescription = Self.taskDescription(id: id, relPath: relPath)
        Self.setMeta(DownloadTaskMeta(id: id, relPath: relPath), for: task.taskIdentifier)
        taskToId[task.taskIdentifier] = id
        taskToRelativePath[task.taskIdentifier] = relPath
        idToTask[id] = task
        idToPlaylistId[id] = playlistId
        // Resume data kullanıldıysa ilerlemeyi sıfırlamayalım (UI 0'a düşmesin).
        if progress[id] == nil {
            progress[id] = DownloadProgress(totalBytes: 0, downloadedBytes: 0)
        }
        task.resume()
    }

    // MARK: - DB helpers

    private func deleteRow(id: String, removeFile: Bool) async {
        do {
            let existing: DBDownloadedItem? = try await AppDatabase.shared.read { db in
                try DBDownloadedItem.filter(Column("id") == id).fetchOne(db)
            }
            if removeFile, let relPath = existing?.localPath {
                DownloadStorage.removeFile(relativePath: relPath)
            }
            if let remote = existing?.remoteURL {
                DownloadStorage.removePendingFile(forRemoteURL: remote)
            }
            _ = try await AppDatabase.shared.write { db in
                try DBDownloadedItem.filter(Column("id") == id).deleteAll(db)
            }
            dbVersion &+= 1
        } catch {
            // ignore
        }
    }

    private func persistFailed(
        id: String,
        playlistId: UUID,
        streamId: String,
        type: String,
        title: String,
        secondaryTitle: String?,
        imageURL: String?,
        remoteURL: String,
        relPath: String,
        containerExtension: String?,
        seriesId: String?,
        seasonNumber: Int?,
        episodeNumber: Int?,
        errorMessage: String
    ) async {
        _ = try? await AppDatabase.shared.write { db in
            var item = DBDownloadedItem(
                id: id,
                playlistId: playlistId,
                streamId: streamId,
                type: type,
                title: title,
                secondaryTitle: secondaryTitle,
                imageURL: imageURL,
                remoteURL: remoteURL,
                localPath: relPath,
                containerExtension: containerExtension,
                totalBytes: 0,
                downloadedBytes: 0,
                status: DownloadStatus.failed.rawValue,
                errorMessage: errorMessage,
                createdAt: Date(),
                completedAt: nil,
                seriesId: seriesId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber
            )
            try item.save(db)
        }
        dbVersion &+= 1
    }
}

// MARK: - URLSessionDownloadDelegate
// Delegate kuyruğu ayrı bir seri OperationQueue'dur (main değil). Bu yüzden
// delegate metotları `nonisolated`'dır; MainActor state'ine yalnızca
// `Task { @MainActor in ... }` ile erişirler. id/relPath senkron gerektiğinde
// `task.taskDescription` üzerinden okunur.

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskId = downloadTask.taskIdentifier
        guard let meta = Self.resolveMeta(for: downloadTask) else { return }
        let id = meta.id

        // Throttle kararı main dışında (delegate kuyruğunda) verilir — kilitli static
        // durum sayesinde MainActor'a dokunmadan hızlıca hesaplanır.
        let now = Date.timeIntervalSinceReferenceDate
        Self.throttleLock.lock()
        let last = Self.throttleState[taskId]
        let isFinal = totalBytesExpectedToWrite > 0 && totalBytesWritten >= totalBytesExpectedToWrite
        var shouldPublish = false
        var speed: Double = 0
        if isFinal || last == nil || (now - (last?.at ?? 0)) >= downloadProgressPublishInterval {
            if let last, now > last.at {
                let delta = Double(totalBytesWritten - last.bytes)
                if delta > 0 { speed = delta / (now - last.at) }
            }
            Self.throttleState[taskId] = (totalBytesWritten, now)
            shouldPublish = true
        }
        Self.throttleLock.unlock()

        let expected = totalBytesExpectedToWrite
        let written = totalBytesWritten

        if shouldPublish {
            Task { @MainActor [weak self] in
                self?.progress[id] = DownloadProgress(
                    totalBytes: max(0, expected),
                    downloadedBytes: max(0, written),
                    bytesPerSecond: max(0, speed)
                )
            }
        }

        if expected > 0 {
            Task { @MainActor [weak self] in
                guard let self, !self.totalBytesPersistedFor.contains(taskId) else { return }
                self.totalBytesPersistedFor.insert(taskId)
                let total = expected
                Task {
                    _ = try? await AppDatabase.shared.write { db in
                        if var row = try DBDownloadedItem.filter(Column("id") == id).fetchOne(db) {
                            row.totalBytes = Int(total)
                            try row.update(db)
                        }
                    }
                }
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Dosya bu delegate metodu dönünce silinir; SENKRON taşımak zorundayız.
        // id + relPath task'ın kendisinden (taskDescription) ya da kilitli sözlükten
        // okunur — MainActor'a dokunmadan, delegate kuyruğunda güvenle.
        guard let meta = Self.resolveMeta(for: downloadTask) else {
            // Uygulama arka planda uyandırıldığında delegate, DB geri yüklemesi
            // tamamlanmadan çalışabilir → satır henüz eşleşmemiş olur. Bu durumda
            // %100 inmiş dosyayı ASLA çöpe atmayız: kurtarma klasörüne koyarız,
            // `restoreOutstandingTasks` bir sonraki açılışta yerine taşır.
            let remote = downloadTask.originalRequest?.url?.absoluteString ?? ""
            if !remote.isEmpty, DownloadStorage.storePendingFile(from: location, remoteURL: remote) {
                downloadLog.info("didFinish: eşleşmeyen task → kurtarma klasörüne alındı (\(remote, privacy: .public))")
            } else {
                downloadLog.error("didFinish: eşleşmeyen task ve kurtarma başarısız (\(remote, privacy: .public))")
            }
            return
        }
        let id = meta.id
        let relPath = meta.relPath

        let fm = FileManager.default
        let sourceSize: Int64 = {
            guard let attrs = try? fm.attributesOfItem(atPath: location.path) else { return 0 }
            return (attrs[.size] as? Int64) ?? 0
        }()
        guard sourceSize > 0 else {
            Task { @MainActor [weak self] in
                await self?.markFailed(
                    id: id,
                    error: NSError(domain: "Download", code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "Empty download payload"])
                )
            }
            return
        }

        do {
            let destination = try DownloadStorage.ensureParentDirectory(for: relPath)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: location, to: destination)
        } catch {
            Task { @MainActor [weak self] in
                await self?.markFailed(id: id, error: error)
            }
            return
        }

        Task { @MainActor [weak self] in
            await self?.markCompleted(id: id, fallbackSize: sourceSize)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let taskId = task.taskIdentifier
        Self.throttleLock.lock()
        Self.throttleState.removeValue(forKey: taskId)
        Self.throttleLock.unlock()
        Self.clearMeta(for: taskId)

        // Resume data varsa sakla — sonraki denemede sıfırdan değil, kaldığı
        // yerden devam edilsin. (Büyük bölümlerde bu kritik.)
        var resumeData: Data?
        if let ns = error as NSError?,
           let data = ns.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            resumeData = data
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.totalBytesPersistedFor.remove(taskId)
            guard let id = self.taskToId[taskId] else { return }
            self.taskToId.removeValue(forKey: taskId)
            self.taskToRelativePath.removeValue(forKey: taskId)
            self.idToTask.removeValue(forKey: id)
            self.idToPlaylistId.removeValue(forKey: id)

            if let error = error {
                let ns = error as NSError
                // Cancel edildiyse row zaten deleteRow ile silinmişti.
                if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled {
                    return
                }

                // KRİTİK: Dosya zaten %100 inip `markCompleted` ile tamamlandıysa,
                // URLSession'ın geç gelen hatası (bağlantı koptu vb.) yüzünden
                // indirmeyi SIFIRDAN tekrar başlatmayalım. Satır `completed` ise
                // ya da hedef dosya diskte doluysa hatayı yok say.
                if await self.isAlreadyCompleted(id: id) {
                    downloadLog.info("ignore late error id=\(id, privacy: .public) — zaten tamamlandı: \(error.localizedDescription, privacy: .public)")
                    self.autoRetryCountById.removeValue(forKey: id)
                    self.resumeDataById.removeValue(forKey: id)
                    await self.pumpQueue()
                    return
                }

                let attempts = (self.autoRetryCountById[id] ?? 0) + 1
                self.autoRetryCountById[id] = attempts
                if attempts <= Self.maxAutoRetries {
                    downloadLog.info("retry id=\(id, privacy: .public) attempt=\(attempts) — kuyruğun sonuna eklendi: \(error.localizedDescription, privacy: .public)")
                    // Resume data'yı yalnızca ilk denemede kullan; ikinci denemede
                    // hâlâ hata varsa sunucu range desteklemiyor olabilir → temiz başla.
                    if attempts >= 2 {
                        self.resumeDataById.removeValue(forKey: id)
                    } else if let resumeData {
                        self.resumeDataById[id] = resumeData
                    }
                    await self.requeueAfterError(id: id, errorMessage: error.localizedDescription)
                    await self.pumpQueue()
                } else {
                    self.autoRetryCountById.removeValue(forKey: id)
                    self.resumeDataById.removeValue(forKey: id)
                    await self.markFailed(id: id, error: error)
                    await self.pumpQueue()
                }
            } else {
                // Başarılı tamamlanma: markCompleted didFinishDownloadingTo'da çağrıldı.
                self.autoRetryCountById.removeValue(forKey: id)
                self.resumeDataById.removeValue(forKey: id)
                await self.pumpQueue()
            }
        }
    }

    /// Hedef dosya diskte varsa bayt cinsinden boyutu, yoksa nil.
    private static func existingFileSize(relativePath: String) -> Int64? {
        guard let url = try? DownloadStorage.absoluteURL(forRelativePath: relativePath),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64,
              size > 0 else {
            return nil
        }
        return size
    }

    /// Satır `completed` mi ya da hedef dosya diskte gerçekten dolu mu?
    /// Geç gelen URLSession hatalarında yeniden indirmeyi engellemek için kullanılır.
    private func isAlreadyCompleted(id: String) async -> Bool {
        let row: DBDownloadedItem? = try? await AppDatabase.shared.read { db in
            try DBDownloadedItem.filter(Column("id") == id).fetchOne(db)
        }
        guard let row else { return false }
        if row.downloadStatus == .completed { return true }
        // Durum henüz güncellenmemiş olabilir (markCompleted async) — dosyaya bak.
        //
        // ÖNEMLİ: URLSession hedef dosyayı yalnızca `didFinishDownloadingTo`
        // içinde (yani indirme BAŞARIYLA bittiğinde) taşır. Dolayısıyla hedef
        // yolda 0'dan büyük bir dosya varsa indirme tamamlanmıştır. Sunucunun
        // bildirdiği Content-Length gerçek boyuttan farklı olabileceği için
        // boyut karşılaştırması yapmıyoruz — aksi hâlde "%100 oldu, baştan
        // indiriyor" hatası oluşuyordu.
        if let size = Self.existingFileSize(relativePath: row.localPath), size > 0 {
            return true
        }
        return false
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let handler = self.backgroundCompletionHandler
            self.backgroundCompletionHandler = nil
            handler?()
        }
    }

    /// Hata alan bir indirmeyi kuyruğun sonuna geri koyar. `createdAt` güncellenir ki
    /// diğer bekleyenler bloklanmasın.
    private func requeueAfterError(id: String, errorMessage: String) async {
        _ = try? await AppDatabase.shared.write { db in
            if var row = try DBDownloadedItem.filter(Column("id") == id).fetchOne(db) {
                // Tamamlanmış bir satırı asla kuyruğa geri düşürme.
                guard row.downloadStatus != DownloadStatus.completed.rawValue else { return }
                row.status = DownloadStatus.queued.rawValue
                row.errorMessage = errorMessage
                row.createdAt = Date()
                try row.update(db)
            }
        }
        progress.removeValue(forKey: id)
        dbVersion &+= 1
    }

    private func markCompleted(id: String, fallbackSize: Int64 = 0) async {
        let now = Date()
        // DB okuması nadiren de olsa kilitli olabilir — birkaç kez dene,
        // aksi halde satır sonsuza dek "downloading" kalırdı.
        var row: DBDownloadedItem?
        for attempt in 0..<3 {
            row = try? await AppDatabase.shared.read { db in
                try DBDownloadedItem.filter(Column("id") == id).fetchOne(db)
            }
            if row != nil { break }
            if attempt < 2 { try? await Task.sleep(nanoseconds: 150_000_000) }
        }
        guard let row else {
            downloadLog.error("markCompleted id=\(id, privacy: .public) — DB satırı okunamadı")
            progress.removeValue(forKey: id)
            return
        }
        // Zaten tamamlandıysa tekrar yazma (idempotent).
        if row.downloadStatus == .completed { progress.removeValue(forKey: id); return }
        let actualSize: Int64 = {
            guard let url = try? DownloadStorage.absoluteURL(forRelativePath: row.localPath),
                  let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
                return 0
            }
            return (attrs[.size] as? Int64) ?? 0
        }()
        let finalSize = max(actualSize, fallbackSize)
        if finalSize == 0 {
            await markFailed(
                id: id,
                error: NSError(domain: "Download", code: -2,
                               userInfo: [NSLocalizedDescriptionKey: "Downloaded file missing or empty"])
            )
            return
        }
        _ = try? await AppDatabase.shared.write { db in
            if var r = try DBDownloadedItem.filter(Column("id") == id).fetchOne(db) {
                r.status = DownloadStatus.completed.rawValue
                r.completedAt = now
                r.totalBytes = Int(finalSize)
                r.downloadedBytes = Int(finalSize)
                r.errorMessage = nil
                try r.update(db)
            }
        }
        progress.removeValue(forKey: id)
        dbVersion &+= 1

        // إشعار اكتمال التنزيل (f127).
        if TigerFeatureRuntime.shared.isOn("f127"),
           TigerFeatureRuntime.shared.downloadPolicy.notifyOnComplete {
            Self.postCompletionNotification(title: row.title)
        }
    }

    private static func postCompletionNotification(title: String) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "اكتمل التنزيل"
            content.body = title
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "download.complete.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request, withCompletionHandler: nil)
        }
        #endif
    }

    private func markFailed(id: String, error: Error) async {
        _ = try? await AppDatabase.shared.write { db in
            if var row = try DBDownloadedItem.filter(Column("id") == id).fetchOne(db) {
                row.status = DownloadStatus.failed.rawValue
                row.errorMessage = error.localizedDescription
                try row.update(db)
            }
        }
        progress.removeValue(forKey: id)
        dbVersion &+= 1
    }
}
