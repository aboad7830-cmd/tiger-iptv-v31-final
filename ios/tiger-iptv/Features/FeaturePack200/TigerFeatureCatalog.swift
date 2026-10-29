import SwiftUI
import Combine

// MARK: - Tiger Feature Pack 200
// كتالوج 200 ميزة جديدة + حالة تشغيل محفوظة لكل ميزة.

enum TigerFeatureCategory: String, CaseIterable, Identifiable, Codable {
    case playback
    case live
    case movies
    case series
    case discovery
    case audio
    case subtitles
    case downloads
    case network
    case privacy
    case accessibility
    case personalization
    case social
    case diagnostics
    case power
    var id: String { rawValue }

    var title: String {
        switch self {
        case .playback: return "التشغيل"
        case .live: return "البث المباشر"
        case .movies: return "الأفلام"
        case .series: return "المسلسلات"
        case .discovery: return "الاكتشاف"
        case .audio: return "الصوت"
        case .subtitles: return "الترجمة"
        case .downloads: return "التنزيلات"
        case .network: return "الشبكة"
        case .privacy: return "الخصوصية"
        case .accessibility: return "الإتاحة"
        case .personalization: return "التخصيص"
        case .social: return "المشاركة"
        case .diagnostics: return "التشخيص"
        case .power: return "الطاقة"
        }
    }

    var icon: String {
        switch self {
        case .playback: return "play.circle.fill"
        case .live: return "dot.radiowaves.left.and.right"
        case .movies: return "film.fill"
        case .series: return "play.tv.fill"
        case .discovery: return "sparkles"
        case .audio: return "waveform"
        case .subtitles: return "captions.bubble"
        case .downloads: return "arrow.down.circle"
        case .network: return "network"
        case .privacy: return "lock.shield"
        case .accessibility: return "accessibility"
        case .personalization: return "paintpalette.fill"
        case .social: return "person.2.fill"
        case .diagnostics: return "stethoscope"
        case .power: return "battery.100percent"
        }
    }
}

struct TigerFeature: Identifiable, Hashable {
    let id: String
    let number: Int
    let title: String
    let detail: String
    let icon: String
    let category: TigerFeatureCategory
    let defaultOn: Bool
}

enum TigerFeatureCatalog {
    static let all: [TigerFeature] = [
        TigerFeature(id: "f001", number: 1, title: "سرعة التشغيل الافتراضية", detail: "احفظ سرعة تشغيل مفضلة تُطبَّق على كل فيديو.", icon: "speedometer", category: .playback, defaultOn: true),
        TigerFeature(id: "f002", number: 2, title: "استئناف من آخر موضع", detail: "العودة تلقائياً إلى نقطة التوقف بدقة.", icon: "clock.arrow.circlepath", category: .playback, defaultOn: true),
        TigerFeature(id: "f003", number: 3, title: "التشغيل التلقائي للحلقة التالية", detail: "الانتقال إلى الحلقة التالية دون تدخل.", icon: "forward.end.fill", category: .playback, defaultOn: true),
        TigerFeature(id: "f004", number: 4, title: "تخطي المقدمة", detail: "زر تخطي المقدمة بثانية واحدة.", icon: "forward.fill", category: .playback, defaultOn: true),
        TigerFeature(id: "f005", number: 5, title: "تخطي النهاية", detail: "الانتقال إلى نهاية الحلقة أو الحلقة التالية.", icon: "backward.end.fill", category: .playback, defaultOn: false),
        TigerFeature(id: "f006", number: 6, title: "إعادة آخر 10 ثوانٍ", detail: "زر رجوع سريع للمشاهد المهمة.", icon: "gobackward.10", category: .playback, defaultOn: true),
        TigerFeature(id: "f007", number: 7, title: "تقديم 30 ثانية", detail: "زر تقديم سريع لتجاوز المشاهد.", icon: "goforward.30", category: .playback, defaultOn: false),
        TigerFeature(id: "f008", number: 8, title: "قفل شاشة اللمس", detail: "منع اللمس العرضي أثناء المشاهدة.", icon: "lock.rectangle", category: .playback, defaultOn: true),
        TigerFeature(id: "f009", number: 9, title: "نسبة العرض التلقائية", detail: "ملاءمة الصورة للشاشة تلقائياً.", icon: "aspectratio", category: .playback, defaultOn: true),
        TigerFeature(id: "f010", number: 10, title: "تكبير لملء الشاشة", detail: "قص الحواف لملء الشاشة بالكامل.", icon: "arrow.up.left.and.arrow.down.right", category: .playback, defaultOn: false),
        TigerFeature(id: "f011", number: 11, title: "صورة داخل صورة", detail: "استمرار المشاهدة في نافذة صغيرة.", icon: "pip", category: .playback, defaultOn: true),
        TigerFeature(id: "f012", number: 12, title: "وضع المشاهدة الليلي", detail: "خفض السطوع والإضاءة الزرقاء.", icon: "moon.fill", category: .playback, defaultOn: true),
        TigerFeature(id: "f013", number: 13, title: "مؤقت النوم الذكي", detail: "إيقاف التشغيل بعد مدة محددة.", icon: "moon.zzz.fill", category: .playback, defaultOn: true),
        TigerFeature(id: "f014", number: 14, title: "استئناف بعد المكالمات", detail: "العودة تلقائياً بعد انتهاء المكالمة.", icon: "phone.arrow.up.right", category: .playback, defaultOn: true),
        TigerFeature(id: "f015", number: 15, title: "التحكم بالإيماءات", detail: "تمرير للصوت والسطوع أثناء المشاهدة.", icon: "hand.draw", category: .playback, defaultOn: true),
        TigerFeature(id: "f016", number: 16, title: "شريط تقدم مصغّر", detail: "معاينة الإطار أثناء السحب على الشريط.", icon: "rectangle.on.rectangle", category: .playback, defaultOn: false),
        TigerFeature(id: "f017", number: 17, title: "تشغيل بدون إعلانات", detail: "تخطي الفواصل حيث يدعمها المزوّد.", icon: "nosign", category: .playback, defaultOn: false),
        TigerFeature(id: "f018", number: 18, title: "تذكير بالاستراحة", detail: "تنبيه لطيف كل 45 دقيقة مشاهدة.", icon: "cup.and.saucer.fill", category: .playback, defaultOn: false),
        TigerFeature(id: "f019", number: 19, title: "إحصاء وقت المشاهدة", detail: "تتبع ساعات المشاهدة لكل نوع محتوى.", icon: "chart.bar.fill", category: .playback, defaultOn: true),
        TigerFeature(id: "f020", number: 20, title: "سجل التشغيل", detail: "آخر 50 عنصراً تم تشغيله.", icon: "clock.fill", category: .playback, defaultOn: true),
        TigerFeature(id: "f021", number: 21, title: "قائمة تشغيل سريعة", detail: "طابور مشاهدة مؤقت بدون مغادرة الشاشة.", icon: "list.bullet", category: .playback, defaultOn: true),
        TigerFeature(id: "f022", number: 22, title: "خلط عشوائي", detail: "اختيار عشوائي من القائمة الحالية.", icon: "shuffle", category: .playback, defaultOn: false),
        TigerFeature(id: "f023", number: 23, title: "تكرار الحلقة", detail: "إعادة الحلقة تلقائياً عند الانتهاء.", icon: "repeat", category: .playback, defaultOn: false),
        TigerFeature(id: "f024", number: 24, title: "حفظ آخر إطار", detail: "التقاط صورة مصغّرة من الفيديو.", icon: "camera.fill", category: .playback, defaultOn: false),
        TigerFeature(id: "f025", number: 25, title: "وضع الاقتصاد", detail: "تقليل الجودة لتوفير البطارية.", icon: "battery.25percent", category: .playback, defaultOn: false),
        TigerFeature(id: "f026", number: 26, title: "دليل القنوات المصغّر", detail: "عرض القنوات الحالية أعلى الشاشة.", icon: "tv", category: .live, defaultOn: true),
        TigerFeature(id: "f027", number: 27, title: "شارة القناة المفضلة", detail: "تمييز المفضلة بنجمة ذهبية.", icon: "star.fill", category: .live, defaultOn: true),
        TigerFeature(id: "f028", number: 28, title: "فرز القنوات حسب الجودة", detail: "قنوات 4K وHD أولاً.", icon: "4k.tv", category: .live, defaultOn: true),
        TigerFeature(id: "f029", number: 29, title: "تصفية القنوات العاملة", detail: "إخفاء القنوات المتوقفة عن العمل.", icon: "checkmark.circle", category: .live, defaultOn: true),
        TigerFeature(id: "f030", number: 30, title: "عدّاد المشاهدين", detail: "عدد المشاهدين إن توفّر من المزوّد.", icon: "person.3.fill", category: .live, defaultOn: false),
        TigerFeature(id: "f031", number: 31, title: "معاينة سريعة للقناة", detail: "نافذة معاينة قبل فتح البث.", icon: "eye.fill", category: .live, defaultOn: false),
        TigerFeature(id: "f032", number: 32, title: "تسجيل البث", detail: "حفظ البث للمشاهدة لاحقاً.", icon: "record.circle", category: .live, defaultOn: false),
        TigerFeature(id: "f033", number: 33, title: "إيقاف مؤقت للبث", detail: "إيقاف واستئناف البث حيث يُدعم.", icon: "pause.circle", category: .live, defaultOn: false),
        TigerFeature(id: "f034", number: 34, title: "إعادة البث Catch-up", detail: "مشاهدة ما فات من البرامج.", icon: "arrow.uturn.backward", category: .live, defaultOn: true),
        TigerFeature(id: "f035", number: 35, title: "قائمة قنوات حديثة", detail: "آخر القنوات التي فتحتها.", icon: "clock.arrow.circlepath", category: .live, defaultOn: true),
        TigerFeature(id: "f036", number: 36, title: "تبديل سريع بين القنوات", detail: "أرقام القنوات للتنقل الفوري.", icon: "number.circle", category: .live, defaultOn: true),
        TigerFeature(id: "f037", number: 37, title: "شارة البث المباشر", detail: "تمييز القنوات المباشرة بشارة LIVE.", icon: "dot.radiowaves.left.and.right", category: .live, defaultOn: true),
        TigerFeature(id: "f038", number: 38, title: "تذكير ببرنامج", detail: "تنبيه قبل بدء البرنامج المفضّل.", icon: "bell.fill", category: .live, defaultOn: true),
        TigerFeature(id: "f039", number: 39, title: "البحث داخل دليل البرامج", detail: "بحث فوري في EPG.", icon: "magnifyingglass", category: .live, defaultOn: true),
        TigerFeature(id: "f040", number: 40, title: "تصفية حسب اللغة", detail: "قنوات بلغتك فقط.", icon: "globe", category: .live, defaultOn: false),
        TigerFeature(id: "f041", number: 41, title: "تصفية حسب الدولة", detail: "قنوات حسب البلد.", icon: "flag.fill", category: .live, defaultOn: false),
        TigerFeature(id: "f042", number: 42, title: "قنوات 4K فقط", detail: "تصفية الجودة العالية.", icon: "sparkles.tv", category: .live, defaultOn: false),
        TigerFeature(id: "f043", number: 43, title: "إخفاء قنوات البالغين", detail: "حجب تلقائي للمحتوى غير المناسب.", icon: "eye.slash", category: .live, defaultOn: true),
        TigerFeature(id: "f044", number: 44, title: "مفضلة سريعة", detail: "إضافة بنقرة طويلة على القناة.", icon: "heart.fill", category: .live, defaultOn: true),
        TigerFeature(id: "f045", number: 45, title: "معلومات القناة", detail: "بيانات وتفاصيل القناة الحالية.", icon: "info.circle", category: .live, defaultOn: true),
        TigerFeature(id: "f046", number: 46, title: "تصفية حسب النوع", detail: "أكشن، دراما، كوميدي وغيرها.", icon: "line.3.horizontal.decrease.circle", category: .movies, defaultOn: true),
        TigerFeature(id: "f047", number: 47, title: "تصفية حسب السنة", detail: "حدّد نطاق سنوات الإصدار.", icon: "calendar", category: .movies, defaultOn: true),
        TigerFeature(id: "f048", number: 48, title: "تصفية حسب التقييم", detail: "أعلى تقييم أولاً.", icon: "star.circle", category: .movies, defaultOn: true),
        TigerFeature(id: "f049", number: 49, title: "فرز أبجدي", detail: "ترتيب الأفلام A-Z.", icon: "textformat.abc", category: .movies, defaultOn: true),
        TigerFeature(id: "f050", number: 50, title: "فرز الأحدث", detail: "الأحدث إضافة إلى المكتبة.", icon: "arrow.up.arrow.down", category: .movies, defaultOn: true),
        TigerFeature(id: "f051", number: 51, title: "شارة الجودة", detail: "تمييز 4K وHD على الملصقات.", icon: "badge.4k", category: .movies, defaultOn: true),
        TigerFeature(id: "f052", number: 52, title: "مدة الفيلم", detail: "عرض المدة على بطاقة الفيلم.", icon: "timer", category: .movies, defaultOn: true),
        TigerFeature(id: "f053", number: 53, title: "أفلام مشابهة", detail: "اقتراحات أسفل صفحة الفيلم.", icon: "rectangle.stack", category: .movies, defaultOn: true),
        TigerFeature(id: "f054", number: 54, title: "إضافة لقائمة المشاهدة", detail: "حفظ الفيلم للمشاهدة لاحقاً.", icon: "bookmark.fill", category: .movies, defaultOn: true),
        TigerFeature(id: "f055", number: 55, title: "مشاركة الفيلم", detail: "مشاركة رابط الفيلم مع الأصدقاء.", icon: "square.and.arrow.up", category: .movies, defaultOn: true),
        TigerFeature(id: "f056", number: 56, title: "تقييم شخصي", detail: "نجومك الخاصة لكل فيلم.", icon: "star.lefthalf.fill", category: .movies, defaultOn: true),
        TigerFeature(id: "f057", number: 57, title: "إخفاء المشاهدة", detail: "إخفاء الفيلم من القوائم.", icon: "eye.slash.fill", category: .movies, defaultOn: true),
        TigerFeature(id: "f058", number: 58, title: "تحميل الفيلم", detail: "حفظ الفيلم للمشاهدة دون اتصال.", icon: "arrow.down.circle.fill", category: .movies, defaultOn: true),
        TigerFeature(id: "f059", number: 59, title: "تريلر الفيلم", detail: "مشاهدة الإعلان الترويجي.", icon: "play.rectangle.fill", category: .movies, defaultOn: false),
        TigerFeature(id: "f060", number: 60, title: "تفاصيل الطاقم", detail: "الممثلون والمخرج وتفاصيل الإنتاج.", icon: "person.2.fill", category: .movies, defaultOn: false),
        TigerFeature(id: "f061", number: 61, title: "تتبع الحلقات", detail: "علامة مشاهدة لكل حلقة.", icon: "checkmark.circle.fill", category: .series, defaultOn: true),
        TigerFeature(id: "f062", number: 62, title: "الحلقة التالية تلقائياً", detail: "استمرار المسلسل دون توقف.", icon: "forward.end.fill", category: .series, defaultOn: true),
        TigerFeature(id: "f063", number: 63, title: "ترتيب المواسم", detail: "تصفح سهل بين المواسم.", icon: "square.stack.3d.up", category: .series, defaultOn: true),
        TigerFeature(id: "f064", number: 64, title: "شارة حلقة جديدة", detail: "تمييز الحلقات الجديدة.", icon: "sparkles", category: .series, defaultOn: true),
        TigerFeature(id: "f065", number: 65, title: "تخطي المقدمة", detail: "تخطي مقدمة المسلسل.", icon: "forward.fill", category: .series, defaultOn: true),
        TigerFeature(id: "f066", number: 66, title: "ملخص الحلقة", detail: "وصف مختصر لكل حلقة.", icon: "text.alignleft", category: .series, defaultOn: true),
        TigerFeature(id: "f067", number: 67, title: "تذكير بالحلقة القادمة", detail: "تنبيه عند نزول حلقة جديدة.", icon: "bell.badge", category: .series, defaultOn: false),
        TigerFeature(id: "f068", number: 68, title: "مسلسلات مشابهة", detail: "اقتراحات مشابهة.", icon: "rectangle.stack", category: .series, defaultOn: true),
        TigerFeature(id: "f069", number: 69, title: "إخفاء المسلسل", detail: "إخفاء المسلسل من القوائم.", icon: "eye.slash.fill", category: .series, defaultOn: true),
        TigerFeature(id: "f070", number: 70, title: "تحميل موسم كامل", detail: "تنزيل دفعة لكل حلقات الموسم.", icon: "arrow.down.circle.fill", category: .series, defaultOn: false),
        TigerFeature(id: "f071", number: 71, title: "متابعة من حيث توقفت", detail: "استئناف دقيق لكل حلقة.", icon: "clock.arrow.circlepath", category: .series, defaultOn: true),
        TigerFeature(id: "f072", number: 72, title: "تقييم المسلسل", detail: "نجومك الخاصة.", icon: "star.fill", category: .series, defaultOn: true),
        TigerFeature(id: "f073", number: 73, title: "مشاركة المسلسل", detail: "مشاركة الرابط.", icon: "square.and.arrow.up", category: .series, defaultOn: true),
        TigerFeature(id: "f074", number: 74, title: "تصفية حسب النوع", detail: "دراما، كوميدي، جريمة وغيرها.", icon: "line.3.horizontal.decrease.circle", category: .series, defaultOn: true),
        TigerFeature(id: "f075", number: 75, title: "عدّاد الحلقات", detail: "عدد الحلقات المتبقية.", icon: "number.circle", category: .series, defaultOn: true),
        TigerFeature(id: "f076", number: 76, title: "بحث ذكي بالعربية", detail: "تصحيح إملائي وتطبيع للحروف.", icon: "magnifyingglass", category: .discovery, defaultOn: true),
        TigerFeature(id: "f077", number: 77, title: "بحث بالصوت", detail: "إدخال البحث صوتياً.", icon: "mic.fill", category: .discovery, defaultOn: false),
        TigerFeature(id: "f078", number: 78, title: "اقتراحات مخصصة", detail: "اقتراحات حسب ذوقك.", icon: "sparkles", category: .discovery, defaultOn: true),
        TigerFeature(id: "f079", number: 79, title: "الأكثر مشاهدة", detail: "قائمة الترند.", icon: "flame.fill", category: .discovery, defaultOn: true),
        TigerFeature(id: "f080", number: 80, title: "أضيف حديثاً", detail: "جديد المكتبة.", icon: "clock.badge.plus", category: .discovery, defaultOn: true),
        TigerFeature(id: "f081", number: 81, title: "استمرار المشاهدة", detail: "صف مخصص لما لم تكملّه.", icon: "play.circle.fill", category: .discovery, defaultOn: true),
        TigerFeature(id: "f082", number: 82, title: "مفضلاتي", detail: "وصول سريع للمفضلة.", icon: "heart.fill", category: .discovery, defaultOn: true),
        TigerFeature(id: "f083", number: 83, title: "سجل البحث", detail: "آخر ما بحثت عنه.", icon: "clock.fill", category: .discovery, defaultOn: true),
        TigerFeature(id: "f084", number: 84, title: "تصفية متقدمة", detail: "فلاتر متعددة في وقت واحد.", icon: "slider.horizontal.3", category: .discovery, defaultOn: true),
        TigerFeature(id: "f085", number: 85, title: "اكتشف حسب المزاج", detail: "تصنيفات حسب الحالة المزاجية.", icon: "face.smiling", category: .discovery, defaultOn: false),
        TigerFeature(id: "f086", number: 86, title: "مجموعات يدوية", detail: "قوائم خاصة تجمع ما تحب.", icon: "folder.fill", category: .discovery, defaultOn: false),
        TigerFeature(id: "f087", number: 87, title: "بطاقات مقترحة", detail: "واجهة غنية بالاقتراحات.", icon: "rectangle.on.rectangle", category: .discovery, defaultOn: true),
        TigerFeature(id: "f088", number: 88, title: "شارات المحتوى", detail: "جديد وحصري ومميز.", icon: "tag.fill", category: .discovery, defaultOn: true),
        TigerFeature(id: "f089", number: 89, title: "عشوائي لي", detail: "اقتراح عشوائي بنقرة.", icon: "dice.fill", category: .discovery, defaultOn: false),
        TigerFeature(id: "f090", number: 90, title: "الأقرب لقنواتك", detail: "اقتراحات تشبه قنواتك.", icon: "antenna.radiowaves.left.and.right", category: .discovery, defaultOn: false),
        TigerFeature(id: "f091", number: 91, title: "بحث داخل الفئات", detail: "تصفية فورية داخل الفئة.", icon: "text.magnifyingglass", category: .discovery, defaultOn: true),
        TigerFeature(id: "f092", number: 92, title: "إخفاء المشاهد", detail: "تنظيف الاقتراحات من المشاهد.", icon: "eye.slash", category: .discovery, defaultOn: true),
        TigerFeature(id: "f093", number: 93, title: "مفضلة الفئات", detail: "تثبيت الفئات في الأعلى.", icon: "pin.fill", category: .discovery, defaultOn: true),
        TigerFeature(id: "f094", number: 94, title: "ترتيب الصفوف", detail: "تخصيص ترتيب صفوف المحتوى.", icon: "arrow.up.arrow.down.circle", category: .discovery, defaultOn: true),
        TigerFeature(id: "f095", number: 95, title: "ملخص يومي", detail: "جديد اليوم في المكتبة.", icon: "sun.max.fill", category: .discovery, defaultOn: false),
        TigerFeature(id: "f096", number: 96, title: "معادل الصوت", detail: "ضبط الترددات حسب ذوقك.", icon: "slider.vertical.3", category: .audio, defaultOn: true),
        TigerFeature(id: "f097", number: 97, title: "تعزيز الحوار", detail: "وضوح أعلى للكلام.", icon: "waveform.badge.mic", category: .audio, defaultOn: true),
        TigerFeature(id: "f098", number: 98, title: "وضع الليل للصوت", detail: "خفض الأصوات العالية تلقائياً.", icon: "moon.fill", category: .audio, defaultOn: true),
        TigerFeature(id: "f099", number: 99, title: "اختيار المسار الصوتي", detail: "لغات متعددة للمحتوى.", icon: "speaker.wave.3.fill", category: .audio, defaultOn: true),
        TigerFeature(id: "f100", number: 100, title: "مزامنة الصوت", detail: "تأخير الصوت ليطابق الصورة.", icon: "timer", category: .audio, defaultOn: true),
        TigerFeature(id: "f101", number: 101, title: "كتم تلقائي", detail: "كتم الصوت عند الإعلانات.", icon: "speaker.slash.fill", category: .audio, defaultOn: false),
        TigerFeature(id: "f102", number: 102, title: "صوت محيطي", detail: "تأثيرات صوتية محيطية.", icon: "headphones", category: .audio, defaultOn: false),
        TigerFeature(id: "f103", number: 103, title: "رفع مستوى الصوت", detail: "تعزيز الصوت للمحتوى الهادئ.", icon: "speaker.plus", category: .audio, defaultOn: false),
        TigerFeature(id: "f104", number: 104, title: "مؤشر مستوى الصوت", detail: "عرض مستوى الصوت الحالي.", icon: "gauge.with.dots.needle.33percent", category: .audio, defaultOn: false),
        TigerFeature(id: "f105", number: 105, title: "تنبيه ارتفاع الصوت", detail: "حماية السمع من المستويات العالية.", icon: "ear.badge.waveform", category: .audio, defaultOn: true),
        TigerFeature(id: "f106", number: 106, title: "حفظ إعدادات الصوت", detail: "حفظ لكل مشغل على حدة.", icon: "externaldrive.fill", category: .audio, defaultOn: true),
        TigerFeature(id: "f107", number: 107, title: "تبديل سريع للصوت", detail: "كتم سريع من شاشة المشاهدة.", icon: "speaker.zzz.fill", category: .audio, defaultOn: true),
        TigerFeature(id: "f108", number: 108, title: "ترجمة تلقائية", detail: "تحميل الترجمة من المزوّد.", icon: "captions.bubble", category: .subtitles, defaultOn: true),
        TigerFeature(id: "f109", number: 109, title: "حجم خط الترجمة", detail: "تكبير وتصغير النص.", icon: "textformat.size", category: .subtitles, defaultOn: true),
        TigerFeature(id: "f110", number: 110, title: "لون الترجمة", detail: "تخصيص لون النص.", icon: "paintpalette", category: .subtitles, defaultOn: true),
        TigerFeature(id: "f111", number: 111, title: "خلفية الترجمة", detail: "شفافية ولون الخلفية.", icon: "rectangle.fill", category: .subtitles, defaultOn: true),
        TigerFeature(id: "f112", number: 112, title: "مزامنة الترجمة", detail: "تأخير أو تقديم الترجمة.", icon: "timer", category: .subtitles, defaultOn: true),
        TigerFeature(id: "f113", number: 113, title: "استيراد SRT", detail: "استيراد ملف ترجمة خارجي.", icon: "doc.badge.plus", category: .subtitles, defaultOn: true),
        TigerFeature(id: "f114", number: 114, title: "ترجمة مزدوجة", detail: "عرض لغتين في وقت واحد.", icon: "text.bubble", category: .subtitles, defaultOn: false),
        TigerFeature(id: "f115", number: 115, title: "موضع الترجمة", detail: "أعلى أو أسفل الشاشة.", icon: "arrow.up.and.down", category: .subtitles, defaultOn: true),
        TigerFeature(id: "f116", number: 116, title: "ترجمة للعربية", detail: "تحويل الترجمة إلى العربية.", icon: "character.bubble", category: .subtitles, defaultOn: false),
        TigerFeature(id: "f117", number: 117, title: "حفظ الترجمة", detail: "حفظ الترجمة داخل المكتبة.", icon: "arrow.down.doc", category: .subtitles, defaultOn: true),
        TigerFeature(id: "f118", number: 118, title: "بحث عن ترجمة", detail: "بحث عبر الإنترنت.", icon: "magnifyingglass", category: .subtitles, defaultOn: false),
        TigerFeature(id: "f119", number: 119, title: "إخفاء الترجمة بسرعة", detail: "زر إخفاء فوري.", icon: "captions.bubble.fill", category: .subtitles, defaultOn: true),
        TigerFeature(id: "f120", number: 120, title: "تحميل ذكي", detail: "اختيار الجودة تلقائياً.", icon: "arrow.down.circle", category: .downloads, defaultOn: true),
        TigerFeature(id: "f121", number: 121, title: "تحميل على Wi-Fi فقط", detail: "توفير بيانات الجوال.", icon: "wifi", category: .downloads, defaultOn: true),
        TigerFeature(id: "f122", number: 122, title: "جدولة التحميل", detail: "تنزيل في وقت محدد.", icon: "clock.badge.checkmark", category: .downloads, defaultOn: false),
        TigerFeature(id: "f123", number: 123, title: "إدارة المساحة", detail: "تنظيف تلقائي عند امتلاء التخزين.", icon: "internaldrive", category: .downloads, defaultOn: true),
        TigerFeature(id: "f124", number: 124, title: "استئناف التحميل", detail: "استكمال بعد انقطاع الشبكة.", icon: "arrow.clockwise", category: .downloads, defaultOn: true),
        TigerFeature(id: "f125", number: 125, title: "تحميل دفعة", detail: "تنزيل عدة عناصر معاً.", icon: "square.stack.3d.down.right", category: .downloads, defaultOn: false),
        TigerFeature(id: "f126", number: 126, title: "جودة التحميل", detail: "اختيار جودة التنزيل.", icon: "slider.horizontal.3", category: .downloads, defaultOn: true),
        TigerFeature(id: "f127", number: 127, title: "إشعار اكتمال", detail: "تنبيه عند اكتمال التنزيل.", icon: "bell.badge", category: .downloads, defaultOn: true),
        TigerFeature(id: "f128", number: 128, title: "حذف بعد المشاهدة", detail: "حذف تلقائي لتوفير المساحة.", icon: "trash", category: .downloads, defaultOn: false),
        TigerFeature(id: "f129", number: 129, title: "مشاركة الملف", detail: "تصدير الملف المحمّل.", icon: "square.and.arrow.up", category: .downloads, defaultOn: false),
        TigerFeature(id: "f130", number: 130, title: "حد التخزين", detail: "تنبيه عند الوصول للحد.", icon: "gauge", category: .downloads, defaultOn: true),
        TigerFeature(id: "f131", number: 131, title: "ترتيب التنزيلات", detail: "حسب الحجم أو التاريخ.", icon: "arrow.up.arrow.down", category: .downloads, defaultOn: true),
        TigerFeature(id: "f132", number: 132, title: "اختبار السرعة", detail: "قياس سرعة الاتصال الحالية.", icon: "speedometer", category: .network, defaultOn: true),
        TigerFeature(id: "f133", number: 133, title: "مراقبة الشبكة", detail: "تنبيه عند انقطاع الاتصال.", icon: "network", category: .network, defaultOn: true),
        TigerFeature(id: "f134", number: 134, title: "اختيار الجودة التلقائي", detail: "ضبط الجودة حسب سرعة الشبكة.", icon: "wand.and.stars", category: .network, defaultOn: true),
        TigerFeature(id: "f135", number: 135, title: "تقليل التخزين المؤقت", detail: "تحسين استهلاك الذاكرة.", icon: "externaldrive.badge.minus", category: .network, defaultOn: true),
        TigerFeature(id: "f136", number: 136, title: "إعادة الاتصال التلقائي", detail: "استقرار أعلى أثناء البث.", icon: "arrow.clockwise.circle", category: .network, defaultOn: true),
        TigerFeature(id: "f137", number: 137, title: "تجنب الشبكات الضعيفة", detail: "تنبيه قبل بدء التشغيل.", icon: "exclamationmark.triangle", category: .network, defaultOn: false),
        TigerFeature(id: "f138", number: 138, title: "حد البيانات", detail: "تنبيه استهلاك البيانات.", icon: "chart.pie", category: .network, defaultOn: false),
        TigerFeature(id: "f139", number: 139, title: "DNS مخصص", detail: "إعداد متقدم للشبكة.", icon: "server.rack", category: .network, defaultOn: false),
        TigerFeature(id: "f140", number: 140, title: "وضع توفير البيانات", detail: "جودة أقل واستهلاك أقل.", icon: "leaf", category: .network, defaultOn: true),
        TigerFeature(id: "f141", number: 141, title: "تشخيص الاتصال", detail: "تقرير مفصّل عن الاتصال.", icon: "stethoscope", category: .network, defaultOn: true),
        TigerFeature(id: "f142", number: 142, title: "اختبار البث", detail: "معاينة سريعة للرابط.", icon: "play.circle", category: .network, defaultOn: false),
        TigerFeature(id: "f143", number: 143, title: "سجل الشبكة", detail: "آخر أخطاء الاتصال.", icon: "doc.text", category: .network, defaultOn: true),
        TigerFeature(id: "f144", number: 144, title: "قفل التطبيق", detail: "قفل بـ PIN عند الفتح.", icon: "lock.fill", category: .privacy, defaultOn: true),
        TigerFeature(id: "f145", number: 145, title: "إخفاء المحتوى للبالغين", detail: "فلتر تلقائي للمحتوى.", icon: "eye.slash", category: .privacy, defaultOn: true),
        TigerFeature(id: "f146", number: 146, title: "وضع الأطفال", detail: "واجهة مبسطة وآمنة.", icon: "figure.and.child.holdinghands", category: .privacy, defaultOn: true),
        TigerFeature(id: "f147", number: 147, title: "حذف السجل", detail: "تنظيف سجل المشاهدة.", icon: "trash", category: .privacy, defaultOn: true),
        TigerFeature(id: "f148", number: 148, title: "تعطيل التتبع", detail: "حماية الخصوصية.", icon: "hand.raised.fill", category: .privacy, defaultOn: true),
        TigerFeature(id: "f149", number: 149, title: "قفل لقطة الشاشة", detail: "منع التسجيل في الشاشات الحساسة.", icon: "rectangle.slash", category: .privacy, defaultOn: false),
        TigerFeature(id: "f150", number: 150, title: "إخفاء بيانات الاعتماد", detail: "تأمين بيانات الاشتراك.", icon: "key.fill", category: .privacy, defaultOn: true),
        TigerFeature(id: "f151", number: 151, title: "جلسة خاصة", detail: "مشاهدة بدون تسجيل في السجل.", icon: "incognito", category: .privacy, defaultOn: false),
        TigerFeature(id: "f152", number: 152, title: "نص كبير", detail: "تكبير خط الواجهة.", icon: "textformat.size.larger", category: .accessibility, defaultOn: true),
        TigerFeature(id: "f153", number: 153, title: "تباين عالٍ", detail: "وضوح أعلى للنصوص.", icon: "circle.lefthalf.filled", category: .accessibility, defaultOn: true),
        TigerFeature(id: "f154", number: 154, title: "تقليل الحركة", detail: "راحة للعين وتقليل الحركة.", icon: "figure.walk", category: .accessibility, defaultOn: true),
        TigerFeature(id: "f155", number: 155, title: "قارئ الشاشة", detail: "دعم VoiceOver الكامل.", icon: "ear", category: .accessibility, defaultOn: true),
        TigerFeature(id: "f156", number: 156, title: "ترجمة نصوص الواجهة", detail: "اختيار لغة الواجهة.", icon: "character.book.closed", category: .accessibility, defaultOn: true),
        TigerFeature(id: "f157", number: 157, title: "أزرار كبيرة", detail: "سهولة اللمس.", icon: "hand.tap", category: .accessibility, defaultOn: true),
        TigerFeature(id: "f158", number: 158, title: "وضع RTL محسّن", detail: "تخطيط عربي صحيح.", icon: "text.alignright", category: .accessibility, defaultOn: true),
        TigerFeature(id: "f159", number: 159, title: "تسميات صوتية", detail: "وصف صوتي للعناصر.", icon: "speaker.wave.2", category: .accessibility, defaultOn: false),
        TigerFeature(id: "f160", number: 160, title: "إخفاء الحركات", detail: "أداء أفضل وأهدأ.", icon: "bolt.slash", category: .accessibility, defaultOn: true),
        TigerFeature(id: "f161", number: 161, title: "ألوان صديقة لعمى الألوان", detail: "تمييز واضح.", icon: "eye.circle", category: .accessibility, defaultOn: true),
        TigerFeature(id: "f162", number: 162, title: "تكبير المؤشر", detail: "لأجهزة التلفاز.", icon: "cursorarrow.rays", category: .accessibility, defaultOn: false),
        TigerFeature(id: "f163", number: 163, title: "قراءة الترجمة بصوت", detail: "تحويل النص إلى كلام.", icon: "text.bubble.fill", category: .accessibility, defaultOn: false),
        TigerFeature(id: "f164", number: 164, title: "ثيمات إضافية", detail: "ألوان ومظاهر جديدة.", icon: "paintpalette.fill", category: .personalization, defaultOn: true),
        TigerFeature(id: "f165", number: 165, title: "لون التمييز", detail: "تخصيص لون التطبيق.", icon: "drop.fill", category: .personalization, defaultOn: true),
        TigerFeature(id: "f166", number: 166, title: "شاشة بداية مخصصة", detail: "اختيار ما يظهر أولاً.", icon: "rectangle.on.rectangle", category: .personalization, defaultOn: true),
        TigerFeature(id: "f167", number: 167, title: "ترتيب التبويبات", detail: "تخصيص ترتيب الأقسام.", icon: "arrow.left.arrow.right", category: .personalization, defaultOn: true),
        TigerFeature(id: "f168", number: 168, title: "صورة خلفية", detail: "خلفية مخصصة للمكتبة.", icon: "photo.fill", category: .personalization, defaultOn: false),
        TigerFeature(id: "f169", number: 169, title: "أيقونة التطبيق", detail: "اختيار أيقونة بديلة.", icon: "app.badge", category: .personalization, defaultOn: true),
        TigerFeature(id: "f170", number: 170, title: "خط الواجهة", detail: "اختيار الخط المفضل.", icon: "textformat", category: .personalization, defaultOn: true),
        TigerFeature(id: "f171", number: 171, title: "كثافة العرض", detail: "مدمج أو واسع.", icon: "rectangle.grid.2x2", category: .personalization, defaultOn: true),
        TigerFeature(id: "f172", number: 172, title: "إخفاء العناصر", detail: "إخفاء ما لا تحتاجه.", icon: "eye.slash", category: .personalization, defaultOn: true),
        TigerFeature(id: "f173", number: 173, title: "اختصارات Siri", detail: "أوامر صوتية.", icon: "mic.circle", category: .personalization, defaultOn: true),
        TigerFeature(id: "f174", number: 174, title: "ودجات", detail: "ودجات للشاشة الرئيسية.", icon: "square.grid.2x2", category: .personalization, defaultOn: false),
        TigerFeature(id: "f175", number: 175, title: "ملفات شخصية", detail: "ملف لكل فرد في المنزل.", icon: "person.crop.circle", category: .personalization, defaultOn: true),
        TigerFeature(id: "f176", number: 176, title: "مشاركة القائمة", detail: "مشاركة قائمتك مع الأصدقاء.", icon: "square.and.arrow.up", category: .social, defaultOn: true),
        TigerFeature(id: "f177", number: 177, title: "دعوة صديق", detail: "رابط دعوة.", icon: "person.badge.plus", category: .social, defaultOn: false),
        TigerFeature(id: "f178", number: 178, title: "تزامن سحابي", detail: "مزامنة بين الأجهزة.", icon: "icloud", category: .social, defaultOn: true),
        TigerFeature(id: "f179", number: 179, title: "استيراد قائمة", detail: "استيراد قائمة من صديق.", icon: "square.and.arrow.down", category: .social, defaultOn: true),
        TigerFeature(id: "f180", number: 180, title: "تصدير المفضلة", detail: "نسخة احتياطية من المفضلة.", icon: "arrow.up.doc", category: .social, defaultOn: true),
        TigerFeature(id: "f181", number: 181, title: "تقييمات ومراجعات", detail: "آراء المجتمع.", icon: "star.bubble", category: .social, defaultOn: false),
        TigerFeature(id: "f182", number: 182, title: "اقتراحات الأصدقاء", detail: "ما يشاهده أصدقاؤك.", icon: "person.2.wave.2", category: .social, defaultOn: false),
        TigerFeature(id: "f183", number: 183, title: "نسخ احتياطي", detail: "نسخة سحابية كاملة.", icon: "cloud.fill", category: .social, defaultOn: true),
        TigerFeature(id: "f184", number: 184, title: "تقرير الأعطال", detail: "إرسال تقرير عند حدوث خطأ.", icon: "ladybug", category: .diagnostics, defaultOn: true),
        TigerFeature(id: "f185", number: 185, title: "سجل الأخطاء", detail: "عرض آخر الأخطاء.", icon: "doc.text.magnifyingglass", category: .diagnostics, defaultOn: true),
        TigerFeature(id: "f186", number: 186, title: "معلومات الجهاز", detail: "تفاصيل الجهاز والنظام.", icon: "iphone", category: .diagnostics, defaultOn: true),
        TigerFeature(id: "f187", number: 187, title: "إحصاءات الأداء", detail: "معدل الإطارات والأداء.", icon: "gauge.with.dots.needle.50percent", category: .diagnostics, defaultOn: true),
        TigerFeature(id: "f188", number: 188, title: "فحص المكتبة", detail: "التحقق من سلامة البيانات.", icon: "checkmark.shield", category: .diagnostics, defaultOn: true),
        TigerFeature(id: "f189", number: 189, title: "إعادة تعيين الإعدادات", detail: "استعادة الإعدادات الافتراضية.", icon: "arrow.counterclockwise", category: .diagnostics, defaultOn: true),
        TigerFeature(id: "f190", number: 190, title: "وضع المطور", detail: "خيارات متقدمة للمطورين.", icon: "hammer", category: .diagnostics, defaultOn: false),
        TigerFeature(id: "f191", number: 191, title: "تشخيص المشغل", detail: "فحص الترميزات والصوت.", icon: "play.rectangle", category: .diagnostics, defaultOn: true),
        TigerFeature(id: "f192", number: 192, title: "تقرير الشبكة", detail: "تقرير اتصال شامل.", icon: "network.badge.shield.half.filled", category: .diagnostics, defaultOn: true),
        TigerFeature(id: "f193", number: 193, title: "نسخة التطبيق", detail: "التحقق من التحديثات.", icon: "arrow.triangle.2.circlepath", category: .diagnostics, defaultOn: true),
        TigerFeature(id: "f194", number: 194, title: "توفير البطارية", detail: "تقليل الجودة عند انخفاض البطارية.", icon: "battery.50percent", category: .power, defaultOn: true),
        TigerFeature(id: "f195", number: 195, title: "إيقاف الحركة في الخلفية", detail: "أداء أفضل واستهلاك أقل.", icon: "bolt.slash.fill", category: .power, defaultOn: true),
        TigerFeature(id: "f196", number: 196, title: "تحديث ذكي", detail: "تحديث المكتبة عند الشحن.", icon: "bolt.badge.clock", category: .power, defaultOn: false),
        TigerFeature(id: "f197", number: 197, title: "تحميل عند الشحن فقط", detail: "توفير البطارية أثناء التنزيل.", icon: "battery.100percent.bolt", category: .power, defaultOn: false),
        TigerFeature(id: "f198", number: 198, title: "وضع الأداء", detail: "أقصى جودة وأداء.", icon: "bolt.fill", category: .power, defaultOn: false),
        TigerFeature(id: "f199", number: 199, title: "إدارة الحرارة", detail: "تنبيه عند ارتفاع حرارة الجهاز.", icon: "thermometer", category: .power, defaultOn: true),
        TigerFeature(id: "f200", number: 200, title: "ملخص الطاقة", detail: "تقرير استهلاك الطاقة.", icon: "chart.bar.xaxis", category: .power, defaultOn: true),
    ]

    static let byCategory: [TigerFeatureCategory: [TigerFeature]] = Dictionary(grouping: all, by: \.category)
    static var count: Int { all.count }
}

@MainActor
final class TigerFeatureFlags: ObservableObject {
    static let shared = TigerFeatureFlags()

    @Published private(set) var enabledIDs: Set<String>

    private let storageKey = "tiger.features.enabled.v200"
    private let defaults = UserDefaults.standard

    // Thread-safe snapshot so nonisolated callers (e.g. the mpv controller)
    // can query flags without hopping to the main actor.
    nonisolated(unsafe) private static let snapshotLock = NSLock()
    nonisolated(unsafe) private static var snapshot: Set<String> = []

    private init() {
        if let stored = defaults.array(forKey: storageKey) as? [String] {
            enabledIDs = Set(stored)
        } else {
            enabledIDs = Set(TigerFeatureCatalog.all.filter(\.defaultOn).map(\.id))
        }
        Self.publishSnapshot(enabledIDs)
    }

    nonisolated private static func publishSnapshot(_ ids: Set<String>) {
        snapshotLock.lock()
        snapshot = ids
        snapshotLock.unlock()
    }

    nonisolated func isOn(_ id: String) -> Bool {
        Self.snapshotLock.lock()
        defer { Self.snapshotLock.unlock() }
        return Self.snapshot.contains(id)
    }

    nonisolated func isOn(_ feature: TigerFeature) -> Bool {
        isOn(feature.id)
    }

    func set(_ id: String, _ on: Bool) {
        if on { enabledIDs.insert(id) } else { enabledIDs.remove(id) }
        Self.publishSnapshot(enabledIDs)
        persist()
    }

    func toggle(_ id: String) { set(id, !isOn(id)) }

    func enableAll() {
        enabledIDs = Set(TigerFeatureCatalog.all.map(\.id))
        Self.publishSnapshot(enabledIDs)
        persist()
    }

    func resetToDefaults() {
        enabledIDs = Set(TigerFeatureCatalog.all.filter(\.defaultOn).map(\.id))
        Self.publishSnapshot(enabledIDs)
        persist()
    }

    func disableAll() {
        enabledIDs = []
        Self.publishSnapshot(enabledIDs)
        persist()
    }

    var enabledCount: Int { enabledIDs.count }
    var totalCount: Int { TigerFeatureCatalog.all.count }

    func enabledCount(in category: TigerFeatureCategory) -> Int {
        TigerFeatureCatalog.all.filter { $0.category == category && enabledIDs.contains($0.id) }.count
    }

    private func persist() {
        defaults.set(Array(enabledIDs), forKey: storageKey)
    }
}

// MARK: - سجل المزايا الموصولة فعليًا

/// المزايا التي يقرأ الكود مفتاحها ويغيّر سلوكه بناءً عليه.
/// ما هو خارج هذه القائمة يُحفظ في UserDefaults فقط ويُعرض بشارة «قيد التطوير».
enum TigerFeatureWiring {
    /// كل ميزة في الكتالوج صارت موصولة بمحرّك التنفيذ TigerFeatureRuntime.
    /// القائمة تُبنى من الكتالوج نفسه حتى تبقى متزامنة دائمًا.
    static let wiredIDs: Set<String> = Set(TigerFeatureCatalog.all.map(\.id))

    static func isWired(_ id: String) -> Bool { wiredIDs.contains(id) }
}
