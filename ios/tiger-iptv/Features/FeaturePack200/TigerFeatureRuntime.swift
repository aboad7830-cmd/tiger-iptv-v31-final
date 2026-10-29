import Foundation
import SwiftUI
import Combine
import Network
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Tiger Feature Runtime
//
// محرّك تنفيذ حقيقي لمزايا حزمة 200. كل ميزة في الكتالوج لها أثر فعلي:
// إمّا فلترة/فرز/شارات للمحتوى، أو سياسة تشغيل، أو سياسة صوت/ترجمة،
// أو سياسة تنزيل/شبكة/خصوصية/إتاحة/طاقة/تشخيص.
// هذا الملف لا يغيّر أي لون أو حجم خط موجود؛ فقط يقرأ الحالة ويطبّق السلوك.

// MARK: - Badge model

struct TigerContentBadge: Identifiable, Hashable {
    let id: String
    let text: String
    let systemImage: String?
    let priority: Int

    init(_ text: String, systemImage: String? = nil, priority: Int = 0) {
        self.id = text + (systemImage ?? "")
        self.text = text
        self.systemImage = systemImage
        self.priority = priority
    }
}

/// شارة صغيرة تُعرض فوق الملصق. تستخدم أحجامًا صغيرة ثابتة (9pt) ولا تمسّ أي نص قائم.
struct TigerBadgeOverlay: View {
    let badges: [TigerContentBadge]

    var body: some View {
        if !badges.isEmpty {
            HStack(spacing: 4) {
                ForEach(badges.prefix(3)) { badge in
                    HStack(spacing: 2) {
                        if let icon = badge.systemImage {
                            Image(systemName: icon)
                                .font(.system(size: 8, weight: .bold))
                        }
                        Text(badge.text)
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.black.opacity(0.55))
                    )
                }
            }
            .padding(6)
        }
    }
}

// MARK: - Policies

struct TigerPlaybackPolicy {
    var resumeEnabled: Bool = true
    var autoNextEnabled: Bool = true
    var skipIntroEnabled: Bool = true
    var skipIntroSeconds: Int = 85
    var repeatEpisode: Bool = false
    var restReminderMinutes: Int = 45
    var queueEnabled: Bool = true
    var statsEnabled: Bool = true
    var nightMode: Bool = false
    var economyMode: Bool = false
    var gestureVolume: Bool = true
    var gestureBrightness: Bool = true
    var volumeHUD: Bool = false
    var audioBoost: Bool = false
    var dialogueBoost: Bool = false
    var surround: Bool = false
    var volumeWarning: Bool = true
    var saveAudioPerPlayer: Bool = true
    var subtitleAutoLoad: Bool = true
    var subtitleScale: Double = 1.0
    var dualSubtitles: Bool = false
    var arabicSubtitles: Bool = false
    var saveSubtitles: Bool = true
    var subtitlePosition: String = "bottom"
    var subtitleColorHex: String = "#FFFFFF"
    var subtitleBackgroundOpacity: Double = 0.35
}

struct TigerDownloadPolicy {
    var smartQuality: Bool = true
    var wifiOnly: Bool = true
    var scheduled: Bool = false
    var autoCleanup: Bool = true
    var resumeEnabled: Bool = true
    var batchEnabled: Bool = false
    var notifyOnComplete: Bool = true
    var deleteAfterWatch: Bool = false
    var shareEnabled: Bool = false
    var storageLimitGB: Double = 20
    var preferredQuality: String = "auto"
    var sortBy: String = "date"
}

struct TigerPrivacyPolicy {
    var appLock: Bool = false
    var hideAdult: Bool = true
    var kidsMode: Bool = false
    var clearHistoryOnExit: Bool = false
    var blockTracking: Bool = true
    var incognito: Bool = false
    var hideCredentials: Bool = true
    var blockScreenshots: Bool = false
}

struct TigerAccessibilityPolicy {
    var largeText: Bool = false
    var highContrast: Bool = false
    var reduceMotion: Bool = false
    var voiceOverLabels: Bool = true
    var bigButtons: Bool = false
    var rtlEnhanced: Bool = true
    var hideAnimations: Bool = false
    var colorBlindFriendly: Bool = true
    var biggerCursor: Bool = false
    var speakSubtitles: Bool = false
}

struct TigerPowerPolicy {
    var batterySaver: Bool = true
    var pauseBackgroundMotion: Bool = true
    var smartUpdate: Bool = false
    var chargeOnlyDownloads: Bool = false
    var performanceMode: Bool = false
    var thermalGuard: Bool = true
    var energyReport: Bool = true
    var economyPlayback: Bool = false
}

// MARK: - Runtime

@MainActor
final class TigerFeatureRuntime: ObservableObject {
    static let shared = TigerFeatureRuntime()

    /// يُبثّ عند تغيير أي مفتاح ميزة حتى تُعيد الواجهات الحساب.
    @Published private(set) var revision: Int = 0
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var isWiFi: Bool = true
    @Published private(set) var isExpensive: Bool = false

    private let defaults = UserDefaults.standard
    private let flags = TigerFeatureFlags.shared
    private var cancellables = Set<AnyCancellable>()
    private let monitor = NWPathMonitor()

    private enum Keys {
        static let liveLanguage = "tiger.live.language"
        static let liveCountry = "tiger.live.country"
        static let liveDeadIds = "tiger.live.deadIds"
        static let vodGenre = "tiger.vod.genre"
        static let vodYearFrom = "tiger.vod.yearFrom"
        static let vodYearTo = "tiger.vod.yearTo"
        static let vodMinRating = "tiger.vod.minRating"
        static let seriesGenre = "tiger.series.genre"
        static let subtitleScale = "tiger.subtitle.scale"
        static let subtitleColor = "tiger.subtitle.color"
        static let subtitleBackground = "tiger.subtitle.background"
        static let subtitlePosition = "tiger.subtitle.position"
        static let storageLimit = "tiger.downloads.storageLimitGB"
        static let downloadQuality = "tiger.downloads.quality"
        static let downloadSort = "tiger.downloads.sort"
        static let errorLog = "tiger.diagnostics.errorLog"
    }

    private init() {
        flags.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.revision &+= 1
            }
            .store(in: &cancellables)

        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let wifi = path.usesInterfaceType(.wifi)
            let expensive = path.isExpensive
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isOnline != online { self.isOnline = online }
                if self.isWiFi != wifi { self.isWiFi = wifi }
                if self.isExpensive != expensive { self.isExpensive = expensive }
            }
        }
        monitor.start(queue: DispatchQueue(label: "tiger.feature.network"))
    }

    // MARK: Flag access

    nonisolated func isOn(_ id: String) -> Bool { TigerFeatureFlags.shared.isOn(id) }

    nonisolated private func bool(_ id: String, _ key: String, _ fallback: Bool) -> Bool {
        guard isOn(id) else { return false }
        let d = UserDefaults.standard
        if d.object(forKey: key) == nil { return fallback }
        return d.bool(forKey: key)
    }

    nonisolated private func int(_ id: String, _ key: String, _ fallback: Int) -> Int {
        guard isOn(id) else { return fallback }
        let value = UserDefaults.standard.integer(forKey: key)
        return value == 0 ? fallback : value
    }

    nonisolated private func double(_ id: String, _ key: String, _ fallback: Double) -> Double {
        guard isOn(id) else { return fallback }
        let d = UserDefaults.standard
        if d.object(forKey: key) == nil { return fallback }
        return d.double(forKey: key)
    }

    nonisolated private func string(_ id: String, _ key: String, _ fallback: String) -> String {
        guard isOn(id) else { return fallback }
        return UserDefaults.standard.string(forKey: key) ?? fallback
    }

    // MARK: Policies

    nonisolated var playbackPolicy: TigerPlaybackPolicy {
        var p = TigerPlaybackPolicy()
        p.resumeEnabled = bool("f002", "tiger.playback.resume", true)
        p.autoNextEnabled = bool("f003", "tiger.playback.autoNext", true)
        p.skipIntroEnabled = bool("f004", "tiger.playback.skipIntro", true)
        p.skipIntroSeconds = int("f004", "tiger.playback.skipIntroSeconds", 85)
        p.repeatEpisode = bool("f023", "tiger.playback.repeat", false)
        p.restReminderMinutes = int("f018", "tiger.playback.restMinutes", 45)
        p.queueEnabled = bool("f021", "tiger.playback.queue", true)
        p.statsEnabled = bool("f019", "tiger.playback.stats", true)
        p.nightMode = bool("f012", "tiger.playback.nightMode", false)
        p.economyMode = bool("f025", "tiger.playback.economy", false)
        p.gestureVolume = bool("f015", "tiger.playback.gestureVolume", true)
        p.gestureBrightness = bool("f015", "tiger.playback.gestureBrightness", true)
        p.volumeHUD = bool("f104", "tiger.audio.volumeHUD", false)
        p.audioBoost = bool("f103", "tiger.audio.boost", false)
        p.dialogueBoost = bool("f097", "tiger.audio.dialogue", false)
        p.surround = bool("f102", "tiger.audio.surround", false)
        p.volumeWarning = bool("f105", "tiger.audio.warning", true)
        p.saveAudioPerPlayer = bool("f106", "tiger.audio.perPlayer", true)
        p.subtitleAutoLoad = bool("f108", "tiger.subtitle.auto", true)
        p.subtitleScale = double("f109", Keys.subtitleScale, 1.0)
        p.subtitleColorHex = string("f110", Keys.subtitleColor, "#FFFFFF")
        p.subtitleBackgroundOpacity = double("f111", Keys.subtitleBackground, 0.35)
        p.subtitlePosition = string("f115", Keys.subtitlePosition, "bottom")
        p.dualSubtitles = bool("f114", "tiger.subtitle.dual", false)
        p.arabicSubtitles = bool("f116", "tiger.subtitle.arabic", false)
        p.saveSubtitles = bool("f117", "tiger.subtitle.save", true)
        return p
    }

    nonisolated var downloadPolicy: TigerDownloadPolicy {
        var p = TigerDownloadPolicy()
        p.smartQuality = bool("f120", "tiger.downloads.smartQuality", true)
        p.wifiOnly = bool("f121", "tiger.downloads.wifiOnly", true)
        p.scheduled = bool("f122", "tiger.downloads.scheduled", false)
        p.autoCleanup = bool("f123", "tiger.downloads.autoCleanup", true)
        p.resumeEnabled = bool("f124", "tiger.downloads.resume", true)
        p.batchEnabled = bool("f125", "tiger.downloads.batch", false)
        p.notifyOnComplete = bool("f127", "tiger.downloads.notify", true)
        p.deleteAfterWatch = bool("f128", "tiger.downloads.deleteAfterWatch", false)
        p.shareEnabled = bool("f129", "tiger.downloads.share", false)
        p.storageLimitGB = double("f130", Keys.storageLimit, 20)
        p.preferredQuality = string("f126", Keys.downloadQuality, "auto")
        p.sortBy = string("f131", Keys.downloadSort, "date")
        return p
    }

    nonisolated var privacyPolicy: TigerPrivacyPolicy {
        var p = TigerPrivacyPolicy()
        p.appLock = bool("f144", "tiger.privacy.appLock", false)
        p.hideAdult = bool("f145", "tiger.privacy.hideAdult", true)
        p.kidsMode = bool("f146", "tiger.privacy.kidsMode", false)
        p.clearHistoryOnExit = bool("f147", "tiger.privacy.clearHistory", false)
        p.blockTracking = bool("f148", "tiger.privacy.blockTracking", true)
        p.blockScreenshots = bool("f149", "tiger.privacy.blockScreenshots", false)
        p.hideCredentials = bool("f150", "tiger.privacy.hideCredentials", true)
        p.incognito = bool("f151", "tiger.privacy.incognito", false)
        return p
    }

    nonisolated var accessibilityPolicy: TigerAccessibilityPolicy {
        var p = TigerAccessibilityPolicy()
        p.largeText = bool("f152", "tiger.access.largeText", false)
        p.highContrast = bool("f153", "tiger.access.highContrast", false)
        p.reduceMotion = bool("f154", "tiger.access.reduceMotion", false)
        p.voiceOverLabels = bool("f155", "tiger.access.voiceOver", true)
        p.bigButtons = bool("f157", "tiger.access.bigButtons", false)
        p.rtlEnhanced = bool("f158", "tiger.access.rtl", true)
        p.hideAnimations = bool("f160", "tiger.access.hideAnimations", false)
        p.colorBlindFriendly = bool("f161", "tiger.access.colorBlind", true)
        p.biggerCursor = bool("f162", "tiger.access.biggerCursor", false)
        p.speakSubtitles = bool("f163", "tiger.access.speakSubtitles", false)
        return p
    }

    nonisolated var powerPolicy: TigerPowerPolicy {
        var p = TigerPowerPolicy()
        p.batterySaver = bool("f194", "tiger.power.batterySaver", true)
        p.pauseBackgroundMotion = bool("f195", "tiger.power.pauseMotion", true)
        p.smartUpdate = bool("f196", "tiger.power.smartUpdate", false)
        p.chargeOnlyDownloads = bool("f197", "tiger.power.chargeOnly", false)
        p.performanceMode = bool("f198", "tiger.power.performance", false)
        p.thermalGuard = bool("f199", "tiger.power.thermalGuard", true)
        p.energyReport = bool("f200", "tiger.power.report", true)
        p.economyPlayback = bool("f025", "tiger.playback.economy", false)
        return p
    }

    // MARK: Live filtering

    private static let adultTokens = ["xxx", "adult", "+18", "18+", "porn", "erotic", "للبالغين", "اباحي", "إباحي"]

    func isAdultChannel(name: String, categoryName: String) -> Bool {
        let haystack = (name + " " + categoryName).lowercased()
        return Self.adultTokens.contains { haystack.contains($0) }
    }

    static func qualityRank(_ name: String) -> Int {
        let n = name.lowercased()
        if n.contains("4k") || n.contains("uhd") || n.contains("2160") { return 0 }
        if n.contains("fhd") || n.contains("1080") { return 1 }
        if n.contains("hd") { return 2 }
        return 3
    }

    func deadLiveIds() -> Set<Int> {
        guard isOn("f029") else { return [] }
        let raw = defaults.stringArray(forKey: Keys.liveDeadIds) ?? []
        return Set(raw.compactMap(Int.init))
    }

    func markLiveDead(_ streamId: Int) {
        var raw = Set(defaults.stringArray(forKey: Keys.liveDeadIds) ?? [])
        raw.insert(String(streamId))
        defaults.set(Array(raw), forKey: Keys.liveDeadIds)
    }

    func clearDeadLive() {
        defaults.removeObject(forKey: Keys.liveDeadIds)
    }

    func filterLive(_ items: [LiveStreamWithCategory]) -> [LiveStreamWithCategory] {
        var result = items

        if isOn("f043") || (isOn("f145") && privacyPolicy.hideAdult) {
            result = result.filter { !isAdultChannel(name: $0.stream.name, categoryName: $0.categoryName) }
        }

        if isOn("f042") {
            result = result.filter { Self.qualityRank($0.stream.name) == 0 }
        }

        if isOn("f040") {
            let language = (defaults.string(forKey: Keys.liveLanguage) ?? "").lowercased()
            if !language.isEmpty {
                result = result.filter { $0.stream.name.lowercased().contains(language) }
            }
        }

        if isOn("f041") {
            let country = (defaults.string(forKey: Keys.liveCountry) ?? "").lowercased()
            if !country.isEmpty {
                result = result.filter {
                    $0.stream.name.lowercased().contains(country) ||
                    $0.categoryName.lowercased().contains(country)
                }
            }
        }

        let dead = deadLiveIds()
        if !dead.isEmpty {
            result = result.filter { !dead.contains($0.stream.streamId) }
        }

        return sortLive(result)
    }

    func sortLive(_ items: [LiveStreamWithCategory]) -> [LiveStreamWithCategory] {
        if isOn("f028") {
            return items.sorted { a, b in
                let ra = Self.qualityRank(a.stream.name)
                let rb = Self.qualityRank(b.stream.name)
                if ra != rb { return ra < rb }
                return a.stream.sortIndex < b.stream.sortIndex
            }
        }
        return items
    }

    // MARK: VOD filtering

    static func year(from raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        return Int(raw.prefix(4))
    }

    static func ratingValue(_ stream: DBVODStream) -> Double {
        if let value = stream.rating5Based, value > 0 { return value }
        if let raw = stream.rating, let value = Double(raw.replacingOccurrences(of: ",", with: ".")) {
            return value
        }
        return 0
    }

    static func ratingValue(_ series: DBSeries) -> Double {
        if let value = series.rating5Based, value > 0 { return value }
        if let raw = series.rating, let value = Double(raw.replacingOccurrences(of: ",", with: ".")) {
            return value
        }
        return 0
    }

    func filterVOD(_ items: [VODWithCategory], watchedIds: Set<Int> = []) -> [VODWithCategory] {
        var result = items

        if isOn("f057"), !watchedIds.isEmpty {
            result = result.filter { !watchedIds.contains($0.stream.streamId) }
        }

        if isOn("f046") {
            let genre = (defaults.string(forKey: Keys.vodGenre) ?? "").lowercased()
            if !genre.isEmpty {
                result = result.filter {
                    ($0.stream.genre ?? "").lowercased().contains(genre) ||
                    ($0.stream.name).lowercased().contains(genre)
                }
            }
        }

        if isOn("f047") {
            let from = defaults.integer(forKey: Keys.vodYearFrom)
            let to = defaults.integer(forKey: Keys.vodYearTo)
            if from > 0 || to > 0 {
                result = result.filter { item in
                    guard let year = Self.year(from: item.stream.releaseDate) else { return false }
                    if from > 0 && year < from { return false }
                    if to > 0 && year > to { return false }
                    return true
                }
            }
        }

        if isOn("f048") {
            let minRating = defaults.double(forKey: Keys.vodMinRating)
            if minRating > 0 {
                result = result.filter { Self.ratingValue($0.stream) >= minRating }
            }
        }

        return sortVOD(result)
    }

    func sortVOD(_ items: [VODWithCategory]) -> [VODWithCategory] {
        if isOn("f049") {
            return items.sorted { $0.stream.name.localizedCaseInsensitiveCompare($1.stream.name) == .orderedAscending }
        }
        if isOn("f050") {
            return items.sorted { a, b in
                let ta = Int(a.stream.added ?? "") ?? 0
                let tb = Int(b.stream.added ?? "") ?? 0
                if ta != tb { return ta > tb }
                return a.stream.sortIndex < b.stream.sortIndex
            }
        }
        if isOn("f048") {
            return items.sorted { Self.ratingValue($0.stream) > Self.ratingValue($1.stream) }
        }
        return items
    }

    // MARK: Series filtering

    func filterSeries(_ items: [SeriesWithCategory], watchedIds: Set<Int> = []) -> [SeriesWithCategory] {
        var result = items

        if isOn("f069"), !watchedIds.isEmpty {
            result = result.filter { !watchedIds.contains($0.series.seriesId) }
        }

        if isOn("f074") {
            let genre = (defaults.string(forKey: Keys.seriesGenre) ?? "").lowercased()
            if !genre.isEmpty {
                result = result.filter {
                    ($0.series.genre ?? "").lowercased().contains(genre) ||
                    ($0.series.name).lowercased().contains(genre)
                }
            }
        }

        return sortSeries(result)
    }

    func sortSeries(_ items: [SeriesWithCategory]) -> [SeriesWithCategory] {
        if isOn("f050") {
            return items.sorted { a, b in
                let ta = Int(a.series.lastModified ?? "") ?? 0
                let tb = Int(b.series.lastModified ?? "") ?? 0
                if ta != tb { return ta > tb }
                return a.series.sortIndex < b.series.sortIndex
            }
        }
        if isOn("f049") {
            return items.sorted { $0.series.name.localizedCaseInsensitiveCompare($1.series.name) == .orderedAscending }
        }
        return items
    }

    // MARK: Badges

    func badges(forLive stream: DBLiveStream) -> [TigerContentBadge] {
        var result: [TigerContentBadge] = []
        if isOn("f037") {
            result.append(TigerContentBadge("LIVE", systemImage: "dot.radiowaves.left.and.right", priority: 1))
        }
        if isOn("f034"), stream.supportsCatchup {
            result.append(TigerContentBadge("CATCH-UP", systemImage: "arrow.uturn.backward", priority: 2))
        }
        let rank = Self.qualityRank(stream.name)
        if isOn("f051"), rank <= 2 {
            result.append(TigerContentBadge(rank == 0 ? "4K" : (rank == 1 ? "FHD" : "HD"), priority: 0))
        }
        return result.sorted { $0.priority < $1.priority }
    }

    func badges(forVOD stream: DBVODStream) -> [TigerContentBadge] {
        var result: [TigerContentBadge] = []
        if isOn("f051") {
            let rank = Self.qualityRank(stream.name)
            if rank <= 2 {
                result.append(TigerContentBadge(rank == 0 ? "4K" : (rank == 1 ? "FHD" : "HD"), priority: 0))
            }
        }
        if isOn("f052"), let duration = stream.duration, !duration.isEmpty {
            result.append(TigerContentBadge(duration, systemImage: "clock", priority: 3))
        }
        if isOn("f088"), let added = Int(stream.added ?? ""), added > 0 {
            let days = (Date().timeIntervalSince1970 - Double(added)) / 86_400
            if days >= 0 && days <= 14 {
                result.append(TigerContentBadge("جديد", systemImage: "sparkles", priority: 1))
            }
        }
        return result.sorted { $0.priority < $1.priority }
    }

    func badges(forSeries series: DBSeries) -> [TigerContentBadge] {
        var result: [TigerContentBadge] = []
        if isOn("f051") {
            let rank = Self.qualityRank(series.name)
            if rank <= 2 {
                result.append(TigerContentBadge(rank == 0 ? "4K" : (rank == 1 ? "FHD" : "HD"), priority: 0))
            }
        }
        if isOn("f064"), let modified = Int(series.lastModified ?? ""), modified > 0 {
            let days = (Date().timeIntervalSince1970 - Double(modified)) / 86_400
            if days >= 0 && days <= 14 {
                result.append(TigerContentBadge("حلقات جديدة", systemImage: "sparkles", priority: 1))
            }
        }
        return result.sorted { $0.priority < $1.priority }
    }

    // MARK: Side effects when toggling from Feature Center

    func applySideEffects(for id: String, enabled: Bool) {
        switch id {
        case "f152":
            ThemeManager.shared.largeText = enabled
        case "f154", "f160":
            ThemeManager.shared.reduceMotion = enabled
        case "f147":
            if enabled {
                defaults.set(true, forKey: "tiger.privacy.clearHistory")
            }
        default:
            break
        }
        revision &+= 1
    }

    // MARK: Diagnostics

    func log(error message: String) {
        guard isOn("f184") || isOn("f185") else { return }
        var log = defaults.stringArray(forKey: Keys.errorLog) ?? []
        let stamp = ISO8601DateFormatter().string(from: Date())
        log.insert("[\(stamp)] \(message)", at: 0)
        if log.count > 100 { log = Array(log.prefix(100)) }
        defaults.set(log, forKey: Keys.errorLog)
    }

    var errorLog: [String] {
        defaults.stringArray(forKey: Keys.errorLog) ?? []
    }

    func clearErrorLog() {
        defaults.removeObject(forKey: Keys.errorLog)
    }

    var deviceSummary: String {
        #if os(iOS)
        return "iOS \(ProcessInfo.processInfo.operatingSystemVersionString) • \(UIDevice.current.model)"
        #elseif os(macOS)
        return "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    // MARK: Network helpers

    var canDownloadNow: Bool {
        guard isOnline else { return false }
        let policy = downloadPolicy
        if policy.wifiOnly && !isWiFi { return false }
        if isOn("f140") && isExpensive { return false }
        return true
    }

    var networkSummary: String {
        if !isOnline { return "غير متصل" }
        if isWiFi { return "Wi-Fi" }
        if isExpensive { return "شبكة الجوال" }
        return "شبكة"
    }

    // MARK: Power helpers

    /// جودة مفضّلة بناءً على وضع الاقتصاد/الأداء.
    var preferredPlaybackQuality: String {
        let power = powerPolicy
        if power.performanceMode { return "4K" }
        if power.economyPlayback || power.batterySaver { return "HD" }
        return "auto"
    }
}

// MARK: - Capture shield (f149)

#if os(iOS)
/// غطاء يمنع ظهور المحتوى أثناء تسجيل الشاشة أو أخذ لقطة (ميزة الخصوصية f149).
struct TigerCaptureShield: View {
    @State private var isCaptured: Bool = false

    var body: some View {
        Group {
            if isCaptured {
                ZStack {
                    Color.black
                    VStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 34))
                        Text("المحتوى محمي")
                            .font(.footnote)
                    }
                    .foregroundColor(.white.opacity(0.85))
                }
                .ignoresSafeArea()
            }
        }
        .onAppear { isCaptured = UIScreen.main.isCaptured }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isCaptured = UIScreen.main.isCaptured
        }
    }
}
#else
struct TigerCaptureShield: View {
    var body: some View { EmptyView() }
}
#endif
