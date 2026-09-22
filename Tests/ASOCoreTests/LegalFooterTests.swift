import Testing
import ASOCore

@Suite("Legal footer")
struct LegalFooterTests {
    @Test func appendsLocalizedLabelsOnce() {
        let d = "Great app.\n\n- Feature one"
        let de = LegalFooter.apply(to: d, locale: .deDE, eulaURL: "https://x.com/eula", privacyURL: "https://x.com/privacy")
        #expect(de.hasSuffix("Nutzungsbedingungen (EULA): https://x.com/eula\nDatenschutzrichtlinie: https://x.com/privacy"))
        #expect(de.hasPrefix("Great app."))
        let again = LegalFooter.apply(to: de, locale: .deDE, eulaURL: "https://x.com/eula", privacyURL: "https://x.com/privacy")
        #expect(again == de)                                   // idempotent
        #expect(LegalFooter.strip(de) == "Great app.\n\n- Feature one")
        #expect(LegalFooter.contains(de, eulaURL: "https://x.com/eula", privacyURL: "https://x.com/privacy"))
    }

    @Test func trimsBodyToFit() {
        let long = String(repeating: "line of text\n", count: 400)   // ~5200 chars
        let out = LegalFooter.apply(to: long, locale: .enUS, eulaURL: LegalFooter.appleStandardEULA, privacyURL: "https://x.com/p")
        #expect(out.count <= 4000)
        #expect(out.contains("Privacy Policy: https://x.com/p"))
    }
}
