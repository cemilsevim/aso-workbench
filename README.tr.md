<div align="center">

<img src="docs/media/icon.png" width="128" height="128" alt="ASO Workbench simgesi">

# ASO Workbench

**Mac'inizde, dürüst rakamlarla App Store Optimizasyonu.**
Uygulamanızın hangi aramada kaçıncı olduğunu takip edin, gerçekten kazanabileceğiniz keyword'leri bulun, mağaza sayfanızı her dilde yazıp yayınlayın ve her değişikliğin ne işe yaradığını görün.

[![İndir](https://img.shields.io/github/v/release/mustafakendiguzel/aso-workbench?label=indir&style=flat-square&color=brightgreen)](https://github.com/mustafakendiguzel/aso-workbench/releases/latest)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue?style=flat-square)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange?style=flat-square)
[![Lisans](https://img.shields.io/badge/lisans-MIT%20%2B%20Commons%20Clause-lightgrey?style=flat-square)](LICENSE)

[Kurulum](#kurulum) · [Hızlı başlangıç](#hızlı-başlangıç) · [Özellikler](#neler-yapar) · [Anahtarlar](#bağlantılar-hangi-anahtar-neden) · [Rakamlar nasıl hesaplanır](#rakamlar-nasıl-hesaplanır) · [SSS](#sss)

</div>

<!-- TANITIM (docs/media/demo.gif ve demo.mp4 oluşunca açın: make demo VIDEO=…)
<div align="center">
  <a href="docs/media/demo.mp4"><img src="docs/media/demo.gif" width="880" alt="ASO Workbench kullanımda: keyword takibi, popülerlik ve difficulty, mağaza sayfası yazımı"></a>
  <br>
  <sub>▶ <a href="docs/media/demo.mp4"><b>Videonun tamamını izleyin</b></a> · yukarıdaki önizleme sessizdir ve döngüde oynar</sub>
</div>
-->

<!-- İlk push'tan sonra satır içi oynatıcı da eklenebilir: README'yi github.com'da düzenleyin, docs/media/demo.mp4 dosyasını
     bu yorumun altındaki satıra sürükleyin (ücretsiz hesapta 10 MB'a kadar) ve kaydedin. -->

---

## Neden ASO Workbench

Çoğu ASO aracı her keyword için tek, kendinden emin bir sayı gösterir. Bu sayı çoğu zaman bir tahmindir ve hangi kısmın Apple'dan, hangi kısmın aracın kendisinden geldiğini kimse söylemez.

ASO Workbench başka bir yol izler:

- **Her sayı nereden geldiğini söyler.** Apple'ın kendi popülerliği, herkese açık aramadan yapılan ölçüm ve model tahmini ayrı rozetler taşır, asla karıştırılmaz.
- **"Bulunamadı", "201. sıra" değildir.** Yokluk, hata ve "kontrol edilmedi" ayrı tutulur.
- **Mac'inizde çalışır.** Hesap yok, sunucu yok, veri toplama yok. Anahtarlarınız bilgisayarınızdaki tek bir dosyada kalır.
- **Hiçbir anahtar olmadan çalışır**, eklediğiniz her anahtarla daha da iyileşir.

## Neler yapar

| | |
|---|---|
| 📈 **Takip** | Her keyword için sıra, ülke ve cihaz bazında, gerçek App Store aramasından (ilk 200). Sürümlerinizin işaretlendiği geçmiş grafiği. Δ son sürümünüze göre hesaplanır; tekrar ölçünce kazanç kaybolmaz. Ülke bazında puanlar ve yazılı yorumlar. |
| 🔎 **Araştırma** | Apple'ın yayınladığı yerde Apple'ın popülerliği, başka yerde etiketli bir tahmin. İlk on sonuçtan, tamamen açıklanmış difficulty. **Altın keyword'ler** (gerçek talep, yenilebilir rekabet, başkasının markası değil, uygulamanızla ilgili). Rakibin keyword'lerini içe aktarma. Autocomplete fikirleri. |
| 🌍 **Dünyaya açıl** | Keyword'lerinizi tek seferde başka ülkelerde deneyin — yerel dilde yapay zekâ önerili arama biçimleri dahil — ve kazananları tek tıkla takibe alın. |
| ✍️ **Yazma** | Başlık, alt başlık ve keyword alanını önce kazanabileceğiniz keyword'lerle dolduran yapay zekâ yazarı. *Make better* her kural bulgusunu düzeltir. Tüm dilleri tek seferde yazma, her dil için What's New, Kullanım Koşulları ve Gizlilik bağlantılarının otomatik eklenmesi. |
| 🚀 **Yayınlama** | Taslakları App Store Connect'e gönderin: eksik diller oluşturulur, ekran görüntüleri kopyalanır, yeni sürüm açılır, her yazma geri okunur. İncelemeye hiçbir şey gönderilmez. |
| 🧪 **Ölçme** | Sürümlerin ve değişikliklerin zaman çizelgesi, keyword değerine göre ağırlıklı önce/sonra raporuyla. Apple Ads sonuçlarınız keyword ve ülke bazında. RevenueCat'ten MRR ve abonelikler. |

## Kurulum

### İndirme (en kolayı)

1. [Son sürüm](https://github.com/mustafakendiguzel/aso-workbench/releases/latest) sayfasından **`ASO-Workbench-x.y.z.dmg`** dosyasını indirin.
2. Açın ve **ASO Workbench**'i **Applications** klasörüne sürükleyin.
3. İlk açılışta macOS geliştiriciyi doğrulayamadığını söyler (uygulama ücretsizdir ve notarize edilmemiştir). Uygulamaya sağ tıklayın → **Aç** → **Aç**. Ya da: Sistem Ayarları → Gizlilik ve Güvenlik → **Yine de Aç**.

Yeni sürüm çıktığında uygulama haber verir (kenar çubuğunun altında ya da **ASO Workbench ▸ Check for Updates…**). Yeni sürüm verinizi açmadan önce veriniz otomatik yedeklenir.

### Kaynaktan derleme

macOS 15+ ve Xcode 26 (Swift 6.2) gerekir. Bağımlılık yoktur.

```bash
git clone https://github.com/mustafakendiguzel/aso-workbench.git
cd aso-workbench
make install        # optimize derleme → /Applications/ASO Workbench.app
```

Sonrasında `make update` en son kodu çeker ve yeniden kurar. `make help` tüm komutları listeler.

## Hızlı başlangıç

1. **Add App** (kenar çubuğunun altı) → App Store bağlantınızı yapıştırın. Kategori otomatik gelir.
2. **Keywords** → **Add** → önemsediğiniz keyword'leri her satıra bir tane yazın.
3. **Update ▸ Measure all** → sıralar keyword keyword gelir (her biri yaklaşık 3 saniye; Apple herkese açık aramayı sınırlar).
4. İsteğe bağlı: **Connections** → Apple Ads anahtarını ekleyin → **Update ▸ Refresh popularity**. Artık Apple'ın kendi popülerliğini görürsünüz.
5. Filters ▸ **Golden** uğraşmaya değer keyword'leri gösterir. **Metadata ▸ Write** onları bir mağaza sayfasına dönüştürür.

## Bağlantılar: hangi anahtar, neden

Başlamak için hiçbir anahtar gerekmez. Her biri belirli bir şeyi açar; uygulamadaki **Connections** ekranı her birini adım adım anlatır.

| Bağlantı | Gereklilik | Ne açar | Maliyet |
|---|---|---|---|
| *(yok)* | — | Sıralar, autocomplete, rakipler, difficulty, puanlar, yorumlar | ücretsiz |
| **Apple Ads API** | Önerilen | Apple'ın kendi popülerliği, kampanya sonuçlarınız | ücretsiz, para harcamaz |
| **App Store Connect API** | İsteğe bağlı | Mağaza sayfanızı her dilde çekme ve yayınlama | ücretsiz |
| **OpenRouter** | İsteğe bağlı | Yapay zekâ yazarı, çeviriler, marka/ilgi kontrolleri, popülerlik tahminleri | kullandıkça öde, sentin küçük kesirleri |
| **RevenueCat** | İsteğe bağlı | Overview'da MRR ve abonelikler | ücretsiz |
| **Apple Ads web oturumu** | Gelişmiş | Listelerde olmayan terimler için Apple'ın tam endeksi (belgelenmemiş, risk size ait) | ücretsiz |

Anahtarlar Mac'inizde yalnız sizin okuyabildiğiniz tek bir dosyada durur ve her anahtar yalnız kendi servisine gider. Ayrıntılar ve her anahtarın nasıl alınacağı: **[docs/CONNECTIONS.md](docs/CONNECTIONS.md)** (İngilizce).

## Rakamlar nasıl hesaplanır

### Rakamlar, basitçe

| Sayı | Basit anlamı | İyisi |
|---|---|---|
| **Sıra (Rank)** | Biri bu kelimeyi aradığında uygulamanızın kaçıncı çıktığı. | düşük (#1 en iyisi) |
| **Popülerlik** (5–100) | Bu kelimeyi Apple'ın ölçeğinde ne kadar kişinin aradığı. | yüksek |
| **Difficulty** (0–100) | İlk sayfaya çıkmanın ne kadar zor olduğu — orada zaten duran uygulamaların ne kadar büyük ve odaklı olduğu. | düşük |
| **Opportunity** | Difficulty ile indirilmiş popülerlik: popülerlik × (1 − (difficulty ÷ 100)²). | yüksek |
| **Fit** | Bunu arayan kişinin sizinki gibi bir uygulama isteme olasılığı. | ilgili (≥ %50) |
| **Golden ★** | Popülerlik ≥ 30, difficulty ≤ 45, marka değil, uygulamanızla ilgili. | ★ |

### Popülerlik: önce Apple, sonra tahmin

Apple 1–100 popülerliği yalnız her türün tepesi için (aylık listeler) yayınlar ve 29 Eylül 2025'ten beri altındaki her şey için **5** bildirir. ASO Workbench sırayla şunu gösterir:

1. **Apple'ın liste değeri** (`Apple` rozeti, Apple Ads anahtarı gerekir),
2. **Apple'ın tam endeksi** (`Apple · index` rozeti, isteğe bağlı web oturumu),
3. **model tahmini** (`Derived · est.` rozeti); Apple'ın "5" dediği yerde de **taban terimleri arasında 6–29 sırası**, böylece onları yine de kıyaslayabilirsiniz,
4. hiçbiri yoksa **"< N"** — listedeki en düşük puanın altında.

Tahmin, uygulamayla birlikte gelen küçük bir modelden gelir: beş ülkede Apple'ın gerçek popülerliğiyle etiketlenmiş yaklaşık 55.800 terimle bir kez eğitildi ve yalnız herkese açık ipuçlarını kullanır (autocomplete, arama sonuçları ve bir dil modelinin evet/hayır cevapları). Hiç görmediği terimlerde Apple ile aynı sırayı **0,74** korelasyonla verir ve tipik bir terimde yaklaşık **10 puan** sapar. Sıralamaya yardımcı bir araçtır, her zaman etiketlidir ve Apple'ın sayısı varsa hep o kazanır. **[Nasıl kuruldu ve test edildi →](docs/POPULARITY.md)** (İngilizce)

### Difficulty

Arayan kişinin gerçekten gördüğü **ilk on** herkese açık sonuçtan hesaplanır: ilk üçün ne kadar büyük olduğu (%35), sayfanın geri kalanının ne kadar büyük olduğu (%20), kaçının keyword'ü başlığında taşıdığı (%20), ne kadar köklü (%10), ne kadar aktif güncellendiği (%10) ve ne kadar beğenildiği (%5); Apple sayfayı ilgisiz uygulamalarla doldurduğunda indirim uygulanır. Keyword ayrıntı panelinde her parça görünür. **[Ayrıntılar →](docs/POPULARITY.md#difficulty)**

### Önce / sonra

Her sürüm (otomatik algılanır), yayınladığınız her değişiklik ve eklediğiniz her not bir işaret olur. **Changes** sayfası, sıraları işaretten önce ve sonra, her keyword'ün değerine göre ağırlıklandırarak karşılaştırır — kimsenin aramadığı bir kelimede 50 sıra yükselmek hiçbir şey saymaz.

## Gizlilik ve güvenlik

- Yerel çalışır. ASO Workbench sunucusu, hesabı, analitiği yoktur.
- Uygulama yalnız izin listesindeki host'larla konuşur (Apple, OpenRouter, RevenueCat, güncelleme kontrolü için GitHub) — [tam liste](SECURITY.md).
- Onayınız olmadan App Store Connect'e hiçbir şey yazılmaz; her yazma geri okunur; incelemeye hiçbir şey gönderilmez.
- Anahtarlar: `~/Library/Application Support/ASO Workbench/credentials.json` (izinler 600). Veri: aynı klasörde `store.sqlite` — yedekleyebileceğiniz ya da silebileceğiniz düz bir SQLite dosyası.

Bkz. **[SECURITY.md](SECURITY.md)**.

## Proje yapısı

```
Sources/
├── ASOCore/        saf mantık: modeller, kurallar, difficulty, farklar, özellikler (ağ yok, arayüz yok)
├── ASOProviders/   izin listeli HTTP istemcisinin arkasında Apple, OpenRouter ve RevenueCat bağdaştırıcıları
└── ASOWorkbench/      SwiftUI uygulaması: ekranlar, servisler, SwiftData modeli, tasarım sistemi
Resources/          Info.plist, simge, gömülü popülerlik modeli
scripts/            bundle-app.sh (.app derler), release.sh (.dmg + GitHub sürümü)
docs/               POPULARITY, CONNECTIONS, ARCHITECTURE, RELEASING; tr/ altında Türkçe SwiftUI rehberi
```

Derleyicinin birbirinden ayrı tuttuğu üç katman, Swift 6 katı eşzamanlılık, sıfır bağımlılık. **[Mimari →](docs/ARCHITECTURE.md)** · **[SwiftUI altyapı rehberi (Türkçe) →](docs/tr/swiftui-altyapi-rehberi.md)**

## Geliştirme

```bash
make open      # debug derleyip açar
make test      # birim testleri
make lab       # geliştirici Lab'ı ile açar (popülerlik modelini yeniden eğitmek için)
make dist      # sürüm için .dmg ve .zip üretir (bakımcılar)
```

Sürümler, sürüm numaraları ve güncellemelerin kullanıcılara nasıl ulaştığı: **[docs/RELEASING.md](docs/RELEASING.md)**. Katkı: **[CONTRIBUTING.md](CONTRIBUTING.md)**. Değişiklikler: **[CHANGELOG.md](CHANGELOG.md)**.

## SSS

**Rakamlarım neden başka ASO araçlarından farklı?**
Apple her türün tepesinin altında çok az şey yayınladığı için diğer araçlar boşluğu kendi tahminleriyle doldurur, çoğu zaman bunu söylemeden. ASO Workbench Apple'ın değeri varsa onu gösterir, gerisini etiketler.

**Apple Ads'i bağlamak para harcar mı?**
Hayır. Popülerlik ve rapor uçları salt okunurdur ve çalışan bir kampanya gerektirmez.

**Mağaza sayfamı bozabilir mi?**
Yalnız siz Apply'a basıp onayladığınızda yazar; son çekişinizden beri sayfa değiştiyse reddeder; yazdıktan sonra geri okur ve incelemeye asla göndermez.

**Neden macOS 15?**
macOS 15 gerektiren SwiftData, SwiftUI inspector ve Swift 6 özelliklerini kullanır.

**Verim nerede? Nasıl sıfırdan başlarım?**
`~/Library/Application Support/ASO Workbench/`. Sıfırdan başlamak için uygulamayı kapatıp `store.sqlite`'ı silin; tüm anahtarları kaldırmak için `credentials.json`'ı silin.

## Lisans

**Kullanmak serbest, satmak yasak.** Commons Clause'lu MIT Lisansı: ASO Workbench'i ücretsiz kullanabilir (kendi ticari uygulamalarınız için de), kodu okuyup değiştirebilir ve bu lisansla birlikte paylaşabilirsiniz. Onu, değiştirilmiş bir kopyasını ya da büyük ölçüde onun üzerine kurulu ücretli bir hizmeti satamazsınız. Bkz. [LICENSE](LICENSE).

ASO Workbench'in Apple ile bir bağı yoktur ve Apple tarafından onaylanmamıştır. App Store, Apple Ads ve App Store Connect, Apple Inc.'in ticari markalarıdır.

<div align="center"><sub><a href="README.md">English</a></sub></div>
