# ASO Workbench — SwiftUI / UI-UX altyapı rehberi

Yeni bir macOS aracı kurarken aynen kopyalanabilecek parçalar ve nedenleri. Yalnız uygulama katmanı (`Sources/ASOWorkbench`) anlatılır; ağ, model ve iş mantığı ayrı konudur.

## 1. Paket ve uygulama girişi

- SwiftPM paketi, `.xcodeproj` yok. Uygulama hedefi `Package.swift`'te `.defaultIsolation(MainActor.self)` ile derlenir: görünümler ve servisler otomatik ana aktörde, yalnız değer tipleri `nonisolated` işaretlenir.
- `@main struct App`: tek `Window` sahnesi (`WindowGroup` değil; URL komutları ve Dock tıklaması yeni pencere açmasın diye), `Settings` sahnesi, `.modelContainer(...)` tek noktadan.
- Klavye kısayolları `.commands { CommandGroup / CommandMenu }` ile menü çubuğuna bağlanır; görünümlere `NotificationCenter` bildirimleriyle ulaşır (`post(.measureRequested)` → ilgili görünüm `.onReceive`). Böylece kısayol tanımı tek yerde, dinleyen görünüm istediği yerde.
- `asoworkbench://lab/...` URL şeması `.onOpenURL` ile yakalanır ve bir `LabCommands.handle(url, env:, context:, apps:)` dispatcher'ına gider. Uygulamayı UI'ya dokunmadan komutla test etmenin en ucuz yolu; ilk gün kur.

```swift
Window("ASO Workbench", id: "main") { ContentView().environment(environment).frame(minWidth: 980, minHeight: 620) }
    .modelContainer(environment.container)
    .commands { CommandMenu("Keywords") { Button("Measure This Market") { post(.measureRequested) }.keyboardShortcut("r", modifiers: .command) } }
Settings { SettingsView().environment(environment).modelContainer(environment.container) }
```

## 2. Composition root ve durum

- `AppEnvironment` (`@Observable`): tüm servisler burada kurulur, görünümlere `@Environment(AppEnvironment.self)` ile gelir. Servisler de `@Observable`; `private(set) var isBusy`, `lastMessage`, `progress` gibi alanları UI doğrudan okur. Görünüm hiçbir ağ çağrısı yapmaz, servis metodunu `Task { await env.service.run(...) }` ile tetikler.
- Uzun işler için tek desen: `struct Progress: Equatable { var step = ""; var completed = 0; var total = 0; var isRunning = false }` + `func cancel()` (`Task` saklanır). UI: `ProgressView(value:total:)` ve `Text(progress.step)`. Her servis aynı yapıyı taşıdığı için her sayfa aynı görünür.
- Kullanıcı tercihleri `UserDefaults` destekli `@Observable AppSettings` (didSet ile yazılır). Sayfa içi küçük tercihler (`filtre`, `seçili sekme`) `@AppStorage`. Kenar çubuğu seçimi ve seçili uygulama `@AppStorage` ile `Data` olarak saklanır, açılışta geri yüklenir.
- Veri: SwiftData `@Model`'ler. Görünümlerde `@Query` yalnız üst seviye listeler için; tablo satırları için modelden türetilmiş `nonisolated struct Row: Identifiable, Sendable` üretilir (bkz. 4).

## 3. Yerleşim

- `NavigationSplitView`: sol kenar çubuğu (`SidebarView`, `List(selection:)` + `Section`lar + `.listStyle(.sidebar)`), sağ detay `switch selection`. Seçim `enum SidebarSelection: Hashable, Codable { case section(WorkspaceSection), connections, ideas, training }`.
- Kenar çubuğunun üstünde `safeAreaInset(edge: .top)` ile uygulama değiştirici, altında `safeAreaInset(edge: .bottom)` ile "Add App". Bölümler `enum WorkspaceSection: CaseIterable` (title + SF Symbol).
- Uygulama bağlamı `AppWorkspaceView(app:section:)`'a `.id(app.persistentModelID)` ile verilir: uygulama değişince görünüm sıfırdan kurulur, eski state sızmaz.
- Sağ panel: `.inspector(isPresented:)` (Keywords'te keyword ayrıntısı, Metadata'da kurallar/kapsama). Geniş formlar için `HSplitView` (Changes: sol zaman çizelgesi, sağ etki paneli).
- Boş durumlar hep `ContentUnavailableView(title, systemImage:, description:)`; hiçbir sayfa boş beyaz kalmaz.
- Çok düğmeli sayfada araç çubuğu üç yazılı `Menu`'ye indirilir (Write / Publish / Baseline). Menü altına `Divider()` + `Text(durum)` koymak, düğmenin ne yapacağını okutur. Simge tek başına yetmez.
- Sayfa akışı bir satırda anlatılır: editörün üstünde `HStack { Image(systemName:) ; Text("Flow: A → B → C") }` `.font(.caption)`. Yeni gelen kullanıcı hangi sırayla basacağını görür.

## 4. Tablo deseni (en çok tekrar eden parça)

```swift
nonisolated struct KeywordRow: Identifiable, Sendable {
    let id: PersistentIdentifier
    let text: String
    let popularity: Popularity?      // gösterim için
    let popularitySort: Int          // sıralama için ayrı sayısal anahtar
    let difficultySort: Double
    init(_ k: TrackedKeyword, ...) { ... }   // modelden türet, görünüm modeli okumaz
}
```

- `Table(rows, selection: $selection, sortOrder: $sortOrder)`; sıralanabilir sütunlar `value: \.xSort` ile sayısal alanlara bağlanır (`Optional` ve `Double?` sıralama anahtarı olamaz; `-1` gibi bir taban ver).
- 8'den fazla sütunda derleyici "unable to type-check" verir: sütunları `@TableColumnBuilder<Row, KeyPathComparator<Row>>` ile 2–3 parçaya böl (`columnsA`, `columnsB`), `Table { columnsA; columnsB }`.
- Hücreler küçük, kendi `View`'u olan parçalar (`PopularityCell`, `DeltaLabel`, `RankLabel`); her sayının yanında kaynak rozeti (`SourceBadge(compact: true)`) ve `.help(...)` ile uzun açıklama.
- Seçim: `.contextMenu(forSelectionType: PersistentIdentifier.self)`, `.onDeleteCommand`, `.copyable(...)` (⌘C), silmede `confirmationDialog`. Uzun metin: `.lineLimit(1).truncationMode(.tail).textSelection(.enabled).help(fullText)`.
- Filtre: araç satırında `Button("Filters · n")` + `.popover` içinde `nonisolated struct Filters: Equatable` ve `func allows(row) -> Bool`; hazır ayar düğmeleri (Golden) filtreyi tek seferde kurar.
- Tablo bir `ScrollView` içine konmaz; ya alanı doldurur (`.frame(maxHeight: .infinity)`) ya da satır sayısına göre sabit yükseklik alır. İç içe kaydırma kullanıcıyı sinirlendirir.

## 5. Tasarım sistemi (`DesignSystem/`)

- Sistem stilleri ve semantik renkler; özel tema yok. Koyu mod ve erişilebilirlik bedavaya gelir.
- `SourceBadge` (kaynak, `Capsule` + `.quaternary`), `StatCard` (başlık + içerik, `.background.secondary` yuvarlak kutu), `DeltaLabel` (↑ yeşil / ↓ kırmızı / = / —), `ScoreBand` (popülerlik, difficulty, sıra için tek renk kuralı), `RankLabel`, `InlineMessage(kind:text:)` (info/success/error şerit), `ConnectionStateLabel`, `AppIconView`, `Keycap` + `ShortcutHints` (tablo altında "⌘R measure" satırı) + `ShortcutsSheet`.
- `extension Date { relativeLabel, shortLabel }` gibi biçimleyiciler burada; görünümlerde `DateFormatter` üretilmez.
- Renk kullanırken üçlü koşulda `Color.green : Color.red` yaz; `.green : .primary` karışımı `HierarchicalShapeStyle`/`Color` çakışmasıyla derlenmez.

## 6. Sayfa desenleri

- **Sheet/pencere:** `struct XSheet: View` + `@Environment(\.dismiss)`, üstte başlık + tek satır açıklama + sağda Close, ortada `GroupBox`'lar, altta eylem satırı; `.frame(minWidth:minHeight:)`. Uzun işlerde düğme `ProgressView` + adım metnine dönüşür, sonuçlar aynı pencerede tabloyla listelenir.
- **Çok seçimli liste:** `LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))])` içinde `Toggle(...).toggleStyle(.checkbox)`; "All / None / Best 10" kısayol düğmeleri.
- **Form:** `Form { Section { ... } header: { ... } }.formStyle(.grouped)`; alan sayaçları alanın altında `caption`.
- **Yan panel:** `ScrollView { VStack(spacing: 16) { GroupBox { ... } label: { Text("...") } } }`; her kutu tek konu.
- **Geri alma:** yıkıcı olmayan ama büyük değişikliklerde (Make better) önceki değeri `@State`'te tut, "Undo …" düğmesi göster.
- **Taslak kaydı:** `.onChange(of: fields) { saveDraft($0) }` ve `.task(id: locale) { loadDraft() }`; kullanıcı asla "kaydet"e basmaz.

## 7. Swift 6 eşzamanlılık tuzakları (hepsi yaşandı)

- `@Model` nesneleri `Sendable` değil: `Task.detached`/`TaskGroup`'a model değil `persistentModelID`, `String`, `Int` ver; sonucu ana aktörde modele yaz.
- Ana aktöre bağlı bir kapanışı servise verirken tipi `@MainActor (...) async throws -> T` yaz; aksi hâlde "sending 'app' risks causing data races".
- Statik biçimleyiciler `nonisolated` olamıyorsa fonksiyona çevir; `Date.formatted(...)` nonisolated ve güvenli.
- `@Model` sınıfına yeni alan eklerken varsayılan değer ver (hafif migrasyon); JSON içinde saklanan `Codable` struct'a alan eklerken `decodeIfPresent` ile özel `init(from:)` yaz, yoksa eski kayıtlar okunmaz.

## 8. Derleme, paket, test

- `swift build` → `scripts/bundle-app.sh` `.app` üretir (Info.plist, ikon, CoreML modellerini `coremlcompiler` ile derleyip pakete koyar, ad-hoc `codesign`). `make open`, `make test`.
- Testler Swift Testing (`@Suite`, `@Test`, `#expect`); canlı ağ testleri ortam değişkeniyle opt-in (`.enabled(if:)`), varsayılan atlanır.
- Uygulama günlüğü `AppLog.write("[alan] mesaj")` → `~/Library/Application Support/<App>/app.log`; her servis kendi etiketiyle yazar. Lab URL komutları ile birlikte, "çalıştı mı" sorusunun cevabı hep logdadır.

## 9. UX ilkeleri (koda gömülü olanlar)

- Her sayının yanında kaynağı; tahminler ayrı rozet ve `.help` ile açıklama.
- Yokluk sıfır değildir: "not fetched", "no results", "—" ve "not in top N" ayrı gösterilir.
- Uyarı üretme lüksü yok: bir uyarı verilecekse ya kullanıcı düzeltebilmeli ya da sistem kendi düzeltmeli (Make better). Aksi hâlde uyarı gürültüdür.
- Uzun işler iptal edilebilir, kaldığı yerden devam eder, ilerleme metni "ne yapıyor" der ("DE · “comic maker”").
- Yıkıcı işlemde onay; dış sisteme yazmada (App Store Connect) önce yeniden oku, sonra yaz, sonra geri oku.
