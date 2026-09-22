<div align="center">

<img src="docs/media/icon.png" width="128" height="128" alt="ASO Workbench Symbol">

# ASO Workbench

**App-Store-Optimierung auf deinem Mac, mit ehrlichen Zahlen.**
Verfolge, wo deine App rankt, finde Keywords, die du wirklich gewinnen kannst, schreibe und veröffentliche deine Store-Seite in jeder Sprache und sieh, was jede Änderung bewirkt hat.

[![Download](https://img.shields.io/github/v/release/mustafakendiguzel/aso-workbench?label=download&style=flat-square&color=brightgreen)](https://github.com/mustafakendiguzel/aso-workbench/releases/latest)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue?style=flat-square)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange?style=flat-square)
[![Lizenz](https://img.shields.io/badge/lizenz-MIT%20%2B%20Commons%20Clause-lightgrey?style=flat-square)](LICENSE)

[Installation](#installation) · [Schnellstart](#schnellstart) · [Funktionen](#was-es-kann) · [Schlüssel](#verbindungen-welche-schlüssel-und-warum) · [So entstehen die Zahlen](#so-entstehen-die-zahlen) · [FAQ](#faq)

<sub><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <b>Deutsch</b></sub>

</div>

<div align="center">
  <a href="docs/media/demo.mp4"><img src="docs/media/demo.gif" width="880" alt="ASO Workbench im Einsatz: Keywords verfolgen, Popularität und Schwierigkeit prüfen, eine Store-Seite schreiben"></a>
  <br>
  <sub>▶ <a href="docs/media/demo.mp4"><b>Die ganze Demo ansehen</b></a> · die Vorschau oben ist stumm und läuft in Schleife</sub>
</div>

---

> Die Oberfläche der App ist auf Englisch. Die Namen von Schaltflächen und Menüs unten stehen so da, wie sie in der App erscheinen.

## Warum ASO Workbench

Die meisten ASO-Tools zeigen pro Keyword eine selbstsichere Zahl. Oft ist diese Zahl geraten, und niemand sagt dir, welcher Teil von Apple stammt und welcher vom Tool.

ASO Workbench geht einen anderen Weg:

- **Jede Zahl sagt, woher sie kommt.** Apples eigene Popularität, eine Messung in der öffentlichen Suche und eine Modellschätzung tragen unterschiedliche Kennzeichen und werden nie vermischt.
- **"Nicht gefunden" ist nicht "Platz 201".** Fehlen, Fehler und "nicht geprüft" werden getrennt gespeichert.
- **Es läuft auf deinem Mac.** Kein Konto, kein Server, keine Telemetrie. Deine Schlüssel bleiben in einer Datei auf deinem Rechner.
- **Es funktioniert ohne jeden Schlüssel** und wird mit jedem hinzugefügten Schlüssel besser.

## Was es kann

| | |
|---|---|
| 📈 **Verfolgen** | Das Ranking für jedes Keyword, pro Land und Gerät, aus echten App-Store-Suchen (Top 200). Verlaufsdiagramm mit deinen Releases. Δ gegenüber deinem letzten Release, damit Gewinne beim erneuten Messen nicht verschwinden. Bewertungen pro Land und geschriebene Rezensionen. |
| 🔎 **Recherchieren** | Popularität von Apple, wo Apple sie veröffentlicht, sonst eine gekennzeichnete Schätzung. Schwierigkeit aus den ersten zehn Ergebnissen, vollständig erklärt. **Goldene Keywords** (echte Nachfrage, schlagbare Konkurrenz, nicht die Marke eines anderen, passend zu deiner App). Keywords eines Konkurrenten importieren. Ideen aus der Autovervollständigung. |
| 🌍 **Weltweit** | Probiere deine Keywords in einem Durchgang in anderen Ländern aus, inklusive KI-Vorschlägen in der Landessprache, und verfolge die Gewinner mit einem Klick. |
| ✍️ **Schreiben** | Ein KI-Texter, der Titel, Untertitel und Keyword-Feld zuerst mit den Keywords füllt, die du gewinnen kannst. *Make better* behebt jeden Regelverstoß. Alle Sprachen auf einmal, What's New für alle Sprachen, Links zu Nutzungsbedingungen und Datenschutz werden automatisch ergänzt. |
| 🚀 **Veröffentlichen** | Entwürfe an App Store Connect senden: fehlende Sprachen werden angelegt, Screenshots kopiert, die nächste Version erstellt und jeder Schreibvorgang wird zurückgelesen. Nichts wird zur Prüfung eingereicht. |
| 🧪 **Messen** | Eine Zeitleiste der Releases und Änderungen mit einem Vorher-nachher-Bericht, gewichtet nach dem Wert jedes Keywords. Deine Apple-Ads-Ergebnisse pro Keyword und Land. MRR und Abos aus RevenueCat. |

## Installation

### Download (am einfachsten)

1. Lade **`ASO-Workbench-x.y.z.dmg`** aus dem [neuesten Release](https://github.com/mustafakendiguzel/aso-workbench/releases/latest) herunter.
2. Öffne die Datei und ziehe **ASO Workbench** in **Programme**.
3. Beim ersten Start meldet macOS, dass der Entwickler nicht überprüft werden kann (die App ist kostenlos und nicht notarisiert). Rechtsklick auf die App → **Öffnen** → **Öffnen**. Oder: Systemeinstellungen → Datenschutz & Sicherheit → **Dennoch öffnen**.

Wenn eine neue Version erscheint, sagt die App Bescheid (unten in der Seitenleiste oder über **ASO Workbench ▸ Check for Updates…**). Deine Daten werden automatisch gesichert, bevor eine neue Version sie öffnet.

### Aus dem Quellcode bauen

Benötigt macOS 15 oder neuer und Xcode 26 (Swift 6.2). Keine Abhängigkeiten.

```bash
git clone https://github.com/mustafakendiguzel/aso-workbench.git
cd aso-workbench
make install        # optimierter Build → /Applications/ASO Workbench.app
```

Später: `make update` holt den neuesten Code und installiert neu. `make help` listet alle Befehle.

## Schnellstart

1. **Add App** (unten in der Seitenleiste) → füge den App-Store-Link deiner App ein. Die Kategorie wird automatisch ausgefüllt.
2. **Keywords** → **Add** → gib die Keywords ein, die dich interessieren, eines pro Zeile.
3. **Update ▸ Measure all** → die Rankings kommen Keyword für Keyword (etwa 3 Sekunden pro Keyword; Apple begrenzt die öffentliche Suche).
4. Optional: **Connections** → Apple-Ads-Schlüssel hinzufügen → **Update ▸ Refresh popularity**. Jetzt siehst du Apples eigene Popularität.
5. Filters ▸ **Golden** zeigt die Keywords, um die es sich zu kämpfen lohnt. **Metadata ▸ Write** macht daraus eine Store-Seite.

## Verbindungen: welche Schlüssel und warum

Zum Start brauchst du keinen Schlüssel. Jeder schaltet etwas Bestimmtes frei; der Bildschirm **Connections** in der App erklärt jeden einzeln mit einer Schritt-für-Schritt-Anleitung.

| Verbindung | Bedarf | Schaltet frei | Kosten |
|---|---|---|---|
| *(keine)* | nicht nötig | Rankings, Autovervollständigung, Konkurrenten, Schwierigkeit, Bewertungen, Rezensionen | kostenlos |
| **Apple Ads API** | Empfohlen | Apples eigene Popularität, deine Kampagnenergebnisse | kostenlos, gibt nichts aus |
| **App Store Connect API** | Optional | Deine Store-Seite in jeder Sprache laden und veröffentlichen | kostenlos |
| **OpenRouter** | Optional | KI-Texter, Übersetzungen, Marken- und Relevanzprüfung, Popularitätsschätzungen | nach Verbrauch, Bruchteile eines Cents |
| **RevenueCat** | Optional | MRR und Abos auf der Overview-Seite | kostenlos |
| **Apple-Ads-Websitesitzung** | Fortgeschritten | Apples exakter Index für Begriffe, die in keiner Liste stehen (nicht dokumentiert, auf eigenes Risiko) | kostenlos |

Die Schlüssel liegen in einer Datei auf deinem Mac, die nur du lesen kannst, und jeder Schlüssel geht nur an seinen eigenen Dienst. Details und wie du jeden Schlüssel bekommst: **[docs/CONNECTIONS.md](docs/CONNECTIONS.md)** (auf Englisch).

## So entstehen die Zahlen

### Die Zahlen, einfach erklärt

| Zahl | Einfache Bedeutung | Gut ist |
|---|---|---|
| **Rank** (Ranking) | Wo deine App erscheint, wenn jemand nach diesem Begriff sucht. | niedrig (#1 ist am besten) |
| **Popularity** (5–100) | Wie viele Menschen nach diesem Begriff suchen, auf Apples Skala. | hoch |
| **Difficulty** (0–100) | Wie schwer es ist, auf Seite eins zu kommen, gemessen daran, wie groß und fokussiert die Apps dort schon sind. | niedrig |
| **Opportunity** (Chance) | Popularität, abgezinst um die Schwierigkeit: Popularität × (1 − (Schwierigkeit ÷ 100)²). | hoch |
| **Fit** (Passung) | Wie wahrscheinlich jemand, der danach sucht, eine App wie deine will. | passend (≥ 50%) |
| **Golden ★** | Popularität ≥ 30, Schwierigkeit ≤ 45, keine Marke, passend zu deiner App. | ★ |

### Popularität: zuerst Apple, dann die Schätzung

Apple veröffentlicht eine Popularität von 1 bis 100 nur für die Spitze jeder Kategorie (monatliche Listen) und meldet seit dem 29. September 2025 für alles darunter **5**. ASO Workbench zeigt in dieser Reihenfolge:

1. **Apples Listenwert** (Kennzeichen `Apple`, braucht den Apple-Ads-Schlüssel),
2. **Apples exakten Index** (Kennzeichen `Apple · index`, optionale Websitesitzung),
3. **eine Modellschätzung** (Kennzeichen `Derived · est.`) und für Apples "5" einen **Rang von 6 bis 29 unter den Begriffen am Boden**, damit du sie trotzdem vergleichen kannst,
4. sonst **"< N"**: unter dem niedrigsten Wert in den Listen.

Die Schätzung stammt von einem Modell, das wir selbst trainiert haben und das in der App steckt:

1. **Daten.** Rund 55.800 Suchbegriffe aus fünf Ländern (US, GB, DE, FR, TR).
2. **Lösungsschlüssel.** Jeder Begriff ist mit Apples echter Popularität gekennzeichnet.
3. **Hinweise.** Jeder Begriff wird nur mit öffentlichen Hinweisen beschrieben: Autovervollständigung, Suchergebnisse und **Jev**. Jev (TypeSafe Jev, ein kleines Klassifikationsmodell, das über OpenRouter erreicht wird) beantwortet enge Fragen mit Wahrscheinlichkeiten, etwa "Ist das eine Marke?", "Klingt das nach echter Nachfrage?" und "Welche Kategorie ist das?".
4. **Training.** Zwei kleine CreateML-Modelle haben gelernt, Apples Zahl aus diesen Hinweisen vorherzusagen. Sie werden mit der App ausgeliefert, du musst also nie etwas trainieren.

Im Einsatz beantwortet Jev dieselben Fragen für deine neuen Begriffe, deshalb braucht die Schätzung den OpenRouter-Schlüssel. Bei Begriffen, die es nie gesehen hat, sortiert das Modell sie mit einer Korrelation von **0,74** in dieselbe Reihenfolge wie Apple und liegt bei einem typischen Begriff um etwa **10 Punkte** daneben. Es ist eine Hilfe zum Sortieren, immer gekennzeichnet, und Apples Zahl gewinnt immer. **[Die ganze Methode und die Testergebnisse →](docs/POPULARITY.md#the-model-step-by-step)** (auf Englisch)

### Schwierigkeit

Berechnet aus den **ersten zehn** öffentlichen Ergebnissen, also denen, die ein Suchender wirklich sieht. Gewichtet werden, wie groß die ersten drei sind (35%), wie groß der Rest von Seite eins ist (20%), wie viele den Begriff im Titel tragen (20%), wie etabliert (10%), wie aktiv aktualisiert (10%) und wie gut bewertet (5%) sie sind, mit einem Abschlag, wenn Apple die Seite mit unpassenden Apps füllt. Das Detailfenster des Keywords zeigt jeden Teil. **[Details →](docs/POPULARITY.md#difficulty)**

### Vorher und nachher

Jedes Release (automatisch erkannt), jede veröffentlichte Änderung und jede Notiz wird zu einer Markierung. Die Seite **Changes** vergleicht die Rankings davor und danach, gewichtet nach dem Wert jedes Keywords. 50 Plätze bei einem Begriff, den niemand sucht, zählen nichts.

## Datenschutz und Sicherheit

- Läuft lokal. Kein ASO-Workbench-Server, kein Konto, keine Analyse.
- Die App spricht nur mit einer erlaubten Liste von Hosts (Apple, OpenRouter, RevenueCat und GitHub für die Update-Prüfung). Siehe die [vollständige Liste](SECURITY.md).
- Nichts wird ohne deine Bestätigung in App Store Connect geschrieben; jeder Schreibvorgang wird zurückgelesen; nichts wird zur Prüfung eingereicht.
- Schlüssel: `~/Library/Application Support/ASO Workbench/credentials.json` (Rechte 600). Daten: `store.sqlite` im selben Ordner, eine normale SQLite-Datei, die du sichern oder löschen kannst.

Siehe **[SECURITY.md](SECURITY.md)**.

## Projektstruktur

```
Sources/
├── ASOCore/        reine Logik: Modelle, Regeln, Schwierigkeit, Diffs, Merkmale (kein Netzwerk, keine UI)
├── ASOProviders/   Adapter für Apple, OpenRouter und RevenueCat hinter einem HTTP-Client mit Erlaubnisliste
└── ASOWorkbench/   die SwiftUI-App: Bildschirme, Dienste, SwiftData-Modell, Designsystem
Resources/          Info.plist, Symbol, mitgeliefertes Popularitätsmodell
scripts/            bundle-app.sh (baut die .app), release.sh (.dmg und GitHub-Release)
docs/               POPULARITY, CONNECTIONS, ARCHITECTURE, RELEASING
```

Drei Schichten, die der Compiler trennt, strikte Nebenläufigkeit von Swift 6, keine Abhängigkeiten. **[Architektur →](docs/ARCHITECTURE.md)** (auf Englisch)

## Entwicklung

```bash
make open      # Debug-Build und Start
make test      # Unit-Tests
make lab       # Start mit dem Entwickler-Lab (Popularitätsmodell neu trainieren)
make dist      # .dmg und .zip für ein Release bauen (Maintainer)
```

Releases, Versionierung und wie Updates die Nutzer erreichen: **[docs/RELEASING.md](docs/RELEASING.md)**. Mitmachen: **[CONTRIBUTING.md](CONTRIBUTING.md)**. Änderungen: **[CHANGELOG.md](CHANGELOG.md)**.

## FAQ

**Warum weichen meine Zahlen von anderen ASO-Tools ab?**
Weil Apple unterhalb der Spitze jeder Kategorie sehr wenig veröffentlicht, füllen andere Tools die Lücke mit eigenen Schätzungen, meist ohne es zu sagen. ASO Workbench zeigt Apples Wert, wenn Apple einen hat, und kennzeichnet alles andere.

**Kostet die Verbindung mit Apple Ads Geld?**
Nein. Die Popularitäts- und Berichtsdienste sind nur lesend und brauchen keine laufende Kampagne.

**Kann es meine Store-Seite kaputt machen?**
Es schreibt nur, wenn du Apply drückst und bestätigst, verweigert das Schreiben, wenn sich die Seite seit dem letzten Laden geändert hat, liest nach dem Schreiben zurück und reicht nie etwas zur Prüfung ein.

**Warum macOS 15?**
Es nutzt SwiftData, den SwiftUI-Inspector und Funktionen von Swift 6, die macOS 15 voraussetzen.

**Wo liegen meine Daten? Wie fange ich neu an?**
In `~/Library/Application Support/ASO Workbench/`. Beende die App und lösche `store.sqlite`, um neu anzufangen; lösche `credentials.json`, um alle Schlüssel zu entfernen.

## Lizenz

**Kostenlos nutzbar, nicht verkäuflich.** MIT-Lizenz mit der Commons Clause: Du darfst ASO Workbench kostenlos nutzen (auch für deine eigenen kommerziellen Apps), den Code lesen und ändern und ihn mit dieser Lizenz weitergeben. Du darfst weder die Software noch eine veränderte Kopie noch einen kostenpflichtigen Dienst verkaufen, der hauptsächlich darauf aufbaut. Siehe [LICENSE](LICENSE).

ASO Workbench ist nicht mit Apple verbunden und wird nicht von Apple unterstützt. App Store, Apple Ads und App Store Connect sind Marken von Apple Inc.

<div align="center"><sub><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <b>Deutsch</b></sub></div>
