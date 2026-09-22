import Foundation

/// The legal block Apple expects at the end of a description for apps with subscriptions: Terms of Use (EULA) and
/// Privacy Policy links, labelled in the locale's language, plus an optional note. Deterministic, never written by a model.
public enum LegalFooter {
    public static let appleStandardEULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    static let separator = "———"

    /// (Terms of Use label, Privacy Policy label) per language; English for the rest.
    static let labels: [String: (String, String)] = [
        "en": ("Terms of Use (EULA)", "Privacy Policy"), "de": ("Nutzungsbedingungen (EULA)", "Datenschutzrichtlinie"),
        "fr": ("Conditions d'utilisation (CLUF)", "Politique de confidentialité"), "es": ("Términos de uso (EULA)", "Política de privacidad"),
        "it": ("Termini di utilizzo (EULA)", "Informativa sulla privacy"), "pt": ("Termos de Uso (EULA)", "Política de Privacidade"),
        "nl": ("Gebruiksvoorwaarden (EULA)", "Privacybeleid"), "ja": ("利用規約（EULA）", "プライバシーポリシー"), "ko": ("이용약관 (EULA)", "개인정보 처리방침"),
        "zh-Hans": ("使用条款（EULA）", "隐私政策"), "zh-Hant": ("使用條款（EULA）", "隱私權政策"), "tr": ("Kullanım Koşulları (EULA)", "Gizlilik Politikası"),
        "ru": ("Условия использования (EULA)", "Политика конфиденциальности"), "pl": ("Warunki korzystania (EULA)", "Polityka prywatności"),
        "ar": ("شروط الاستخدام (EULA)", "سياسة الخصوصية"), "hi": ("उपयोग की शर्तें (EULA)", "गोपनीयता नीति"), "id": ("Ketentuan Penggunaan (EULA)", "Kebijakan Privasi"),
        "th": ("ข้อกำหนดการใช้งาน (EULA)", "นโยบายความเป็นส่วนตัว"), "vi": ("Điều khoản sử dụng (EULA)", "Chính sách quyền riêng tư"),
        "sv": ("Användarvillkor (EULA)", "Integritetspolicy"), "no": ("Vilkår for bruk (EULA)", "Personvernerklæring"), "da": ("Vilkår for brug (EULA)", "Privatlivspolitik"),
        "fi": ("Käyttöehdot (EULA)", "Tietosuojakäytäntö"), "cs": ("Podmínky použití (EULA)", "Zásady ochrany osobních údajů"), "sk": ("Podmienky používania (EULA)", "Zásady ochrany osobných údajov"),
        "hu": ("Felhasználási feltételek (EULA)", "Adatvédelmi irányelvek"), "ro": ("Termeni de utilizare (EULA)", "Politica de confidențialitate"), "el": ("Όροι χρήσης (EULA)", "Πολιτική απορρήτου"),
        "uk": ("Умови використання (EULA)", "Політика конфіденційності"), "he": ("תנאי שימוש (EULA)", "מדיניות פרטיות"), "ms": ("Terma Penggunaan (EULA)", "Dasar Privasi"),
        "ca": ("Condicions d'ús (EULA)", "Política de privacitat"), "hr": ("Uvjeti korištenja (EULA)", "Pravila privatnosti"),
    ]

    static func language(of locale: AppLocale) -> String {
        let raw = locale.rawValue
        if raw.hasPrefix("zh-") { return raw }
        return String(raw.split(separator: "-").first ?? Substring(raw))
    }

    /// The block itself, without the surrounding blank line.
    public static func text(locale: AppLocale, eulaURL: String, privacyURL: String, note: String = "") -> String {
        let (terms, privacy) = labels[language(of: locale)] ?? labels["en"]!
        var lines: [String] = [separator]
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { lines.append(n) }
        let e = eulaURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = privacyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !e.isEmpty { lines.append("\(terms): \(e)") }
        if !p.isEmpty { lines.append("\(privacy): \(p)") }
        return lines.joined(separator: "\n")
    }

    /// Removes a footer written by this code (from the separator line to the end) or, for descriptions from elsewhere,
    /// trailing "Label: https://…" lines and blank lines.
    public static func strip(_ description: String) -> String {
        var body = description
        if let range = body.range(of: "\n" + separator, options: .backwards) ?? (body.hasPrefix(separator) ? body.startIndex..<body.index(body.startIndex, offsetBy: separator.count) : nil) {
            body = String(body[..<range.lowerBound])
        } else {
            var lines = body.components(separatedBy: "\n")
            while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty || last.range(of: #"^[^:]{2,60}:\s*https?://\S+$"#, options: .regularExpression) != nil {
                lines.removeLast()
            }
            body = lines.joined(separator: "\n")
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Body + footer within the 4000-character limit (the body is trimmed at a line boundary when needed).
    public static func apply(to description: String, locale: AppLocale, eulaURL: String, privacyURL: String, note: String = "", limit: Int = 4000) -> String {
        let footer = text(locale: locale, eulaURL: eulaURL, privacyURL: privacyURL, note: note)
        guard footer != separator else { return description }
        var body = strip(description)
        let room = limit - footer.count - 2
        if body.count > room {
            var cut = String(body.prefix(room))
            if let nl = cut.lastIndex(of: "\n") { cut = String(cut[..<nl]) }
            body = cut.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return body.isEmpty ? footer : body + "\n\n" + footer
    }

    public static func contains(_ description: String, eulaURL: String, privacyURL: String) -> Bool {
        let e = eulaURL.trimmingCharacters(in: .whitespacesAndNewlines), p = privacyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return (e.isEmpty || description.contains(e)) && (p.isEmpty || description.contains(p)) && !(e.isEmpty && p.isEmpty)
    }
}
