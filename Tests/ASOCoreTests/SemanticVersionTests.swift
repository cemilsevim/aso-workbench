import Testing
import ASOCore

@Suite("Semantic versions (update checks)")
struct SemanticVersionTests {
    @Test func ordering() {
        #expect(SemanticVersion("v1.2.0")! > SemanticVersion("1.1.9")!)
        #expect(SemanticVersion("1.10.0")! > SemanticVersion("1.9.3")!)
        #expect(SemanticVersion("1.2")! == SemanticVersion("1.2.0")!)
        #expect(SemanticVersion("1.2.0-beta.1")! < SemanticVersion("1.2.0")!)
        #expect(SemanticVersion("garbage") == nil)
    }
}
