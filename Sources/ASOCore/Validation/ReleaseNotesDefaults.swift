import Foundation

/// A safe "What's New" for locales that have none: Apple refuses to save a version with an empty field.
public enum ReleaseNotesDefaults {
    static let texts: [String: String] = [
        "en": "Bug fixes and performance improvements.", "de": "Fehlerbehebungen und Leistungsverbesserungen.",
        "fr": "Corrections de bugs et améliorations des performances.", "es": "Corrección de errores y mejoras de rendimiento.",
        "it": "Correzioni di bug e miglioramenti delle prestazioni.", "pt": "Correções de bugs e melhorias de desempenho.",
        "ru": "Исправления ошибок и улучшения производительности.", "tr": "Hata düzeltmeleri ve performans iyileştirmeleri.",
        "ja": "バグ修正とパフォーマンスの改善。", "ko": "버그 수정 및 성능 개선.", "zh-Hans": "修复错误并提升性能。", "zh-Hant": "修正錯誤並提升效能。",
        "nl": "Bugfixes en prestatieverbeteringen.", "pl": "Poprawki błędów i ulepszenia wydajności.", "sv": "Buggfixar och prestandaförbättringar.",
        "no": "Feilrettinger og ytelsesforbedringer.", "da": "Fejlrettelser og ydelsesforbedringer.", "fi": "Virheenkorjauksia ja suorituskyvyn parannuksia.",
        "cs": "Opravy chyb a vylepšení výkonu.", "sk": "Opravy chýb a vylepšenia výkonu.", "hu": "Hibajavítások és teljesítménybeli fejlesztések.",
        "ro": "Remedieri de erori și îmbunătățiri de performanță.", "el": "Διορθώσεις σφαλμάτων και βελτιώσεις απόδοσης.",
        "uk": "Виправлення помилок і покращення продуктивності.", "ar": "إصلاحات للأخطاء وتحسينات في الأداء.", "he": "תיקוני באגים ושיפורי ביצועים.",
        "hi": "बग फ़िक्स और प्रदर्शन में सुधार।", "id": "Perbaikan bug dan peningkatan performa.", "ms": "Pembetulan pepijat dan penambahbaikan prestasi.",
        "th": "แก้ไขข้อบกพร่องและปรับปรุงประสิทธิภาพ", "vi": "Sửa lỗi và cải thiện hiệu năng.", "ca": "Correccions d'errors i millores de rendiment.",
        "hr": "Ispravci pogrešaka i poboljšanja performansi.",
    ]

    public static func text(for locale: AppLocale) -> String {
        let raw = locale.rawValue
        let key = raw.hasPrefix("zh-") ? raw : String(raw.split(separator: "-").first ?? Substring(raw))
        return texts[key] ?? texts["en"]!
    }
}
