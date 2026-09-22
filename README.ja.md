<div align="center">

<img src="docs/media/icon.png" width="128" height="128" alt="ASO Workbench のアイコン">

# ASO Workbench

**Mac で App Store 最適化を。数字はいつも正直に。**
アプリの順位を追跡し、本当に勝てるキーワードを見つけ、すべての言語でストアページを書いて公開し、変更のたびにその効果を確かめられます。

[![ダウンロード](https://img.shields.io/github/v/release/mustafakendiguzel/aso-workbench?label=download&style=flat-square&color=brightgreen)](https://github.com/mustafakendiguzel/aso-workbench/releases/latest)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue?style=flat-square)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange?style=flat-square)
[![ライセンス](https://img.shields.io/badge/license-MIT%20%2B%20Commons%20Clause-lightgrey?style=flat-square)](LICENSE)

[インストール](#インストール) · [クイックスタート](#クイックスタート) · [機能](#機能) · [接続とキー](#接続とキー) · [数字の仕組み](#数字の仕組み) · [よくある質問](#よくある質問)

<sub><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <b>日本語</b> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a></sub>

</div>

<div align="center">
  <a href="docs/media/demo.mp4"><img src="docs/media/demo.gif" width="880" alt="ASO Workbench の使用例"></a>
  <br>
  <sub>▶ <a href="docs/media/demo.mp4"><b>デモ動画を全部見る</b></a> · 上のプレビューは無音でループ再生されます</sub>
</div>

---

> アプリの画面は英語です。以下のボタン名やメニュー名はアプリの表記に合わせています。

## なぜ ASO Workbench なのか

多くの ASO ツールは、キーワードごとに自信ありげな数字をひとつ表示します。その数字はたいてい推測で、どこまでが Apple のデータでどこからがツールの推測なのか、誰も教えてくれません。

ASO Workbench は別の道を選びました。

- **すべての数字に出どころを表示。** Apple 公式の人気度、公開検索での計測値、モデルの推定値にはそれぞれ別のバッジが付き、混ぜ合わされることはありません。
- **「見つからない」は「201 位」ではない。** 存在しない、取得に失敗した、未確認、はそれぞれ区別して記録します。
- **あなたの Mac で動きます。** アカウントもサーバーもテレメトリもありません。キーはあなたの Mac の 1 つのファイルにだけ保存されます。
- **キーがなくても使えて**、キーを追加するたびにできることが増えます。

## 機能

| | |
|---|---|
| 📈 **追跡** | キーワードごとの順位を、国とデバイス別に実際の App Store 検索（上位 200 件）から取得。リリースを書き込んだ履歴グラフ。Δ は直前のリリースを基準にするので、再計測しても伸びが消えません。国別の評価数と書き込みレビュー。 |
| 🔎 **リサーチ** | Apple が公開している場合は Apple の人気度、それ以外はラベル付きの推定値。上位 10 件から計算する、内訳まで説明できる難易度。**ゴールデンキーワード**（本当の需要があり、競争に勝てて、他社のブランドではなく、あなたのアプリに関係する語）。競合アプリのキーワードの取り込み。オートコンプリートからのアイデア。 |
| 🌍 **世界へ** | あなたのキーワードをほかの国でまとめて試せます。AI が提案する現地語の検索表現も含め、有望なものはワンクリックで追跡開始。 |
| ✍️ **書く** | 勝てるキーワードから優先してタイトル、サブタイトル、キーワード欄を埋める AI ライター。*Make better* がルール違反をすべて直します。全言語を一度に作成、全言語の What's New、利用規約とプライバシーポリシーのリンクを自動で追加。 |
| 🚀 **公開** | 下書きを App Store Connect に送信。足りない言語の作成、スクリーンショットのコピー、次のバージョンの作成を行い、書き込み後は必ず読み直して確認します。審査への提出は行いません。 |
| 🧪 **測る** | リリースと変更のタイムラインと、キーワードの価値で重み付けした前後比較レポート。キーワード別、国別の Apple Ads の成果。RevenueCat の MRR とサブスクリプション。 |

## インストール

### ダウンロード（いちばん簡単）

1. [最新リリース](https://github.com/mustafakendiguzel/aso-workbench/releases/latest)から **`ASO-Workbench-x.y.z.dmg`** をダウンロードします。
2. 開いて **ASO Workbench** を **Applications**（アプリケーション）にドラッグします。
3. 初回は、macOS が開発元を確認できないと表示します（アプリは無料で、公証を受けていません）。アプリを右クリック → **開く** → **開く**。または、システム設定 → プライバシーとセキュリティ → **このまま開く**。

新しいバージョンが出ると、アプリが知らせます（サイドバーの下部、または **ASO Workbench ▸ Check for Updates…**）。新しいバージョンがデータを開く前に、データは自動でバックアップされます。

### ソースからビルド

macOS 15 以降と Xcode 26（Swift 6.2）が必要です。外部ライブラリは使っていません。

```bash
git clone https://github.com/mustafakendiguzel/aso-workbench.git
cd aso-workbench
make install        # 最適化ビルド → /Applications/ASO Workbench.app
```

その後は `make update` で最新のコードを取得して再インストールできます。`make help` ですべてのコマンドを表示します。

## クイックスタート

1. **Add App**（サイドバー下部）→ App Store のリンクを貼り付けます。カテゴリは自動で入ります。
2. **Keywords** → **Add** → 気になるキーワードを 1 行に 1 つずつ入力します。
3. **Update ▸ Measure all** → 順位がキーワードごとに表示されます（1 つあたり約 3 秒。Apple が公開検索の頻度を制限しているためです）。
4. 任意：**Connections** → Apple Ads のキーを追加 → **Update ▸ Refresh popularity**。これで Apple 公式の人気度が見られます。
5. Filters ▸ **Golden** で狙う価値のあるキーワードを表示。**Metadata ▸ Write** でそれをストアページの文章にします。

## 接続とキー

使い始めるのにキーは必要ありません。キーはそれぞれ特定の機能を追加します。アプリの **Connections** 画面で、ひとつずつ手順付きで説明しています。

| 接続 | 必要度 | できるようになること | 費用 |
|---|---|---|---|
| *（なし）* | 不要 | 順位、オートコンプリート、競合、難易度、評価、レビュー | 無料 |
| **Apple Ads API** | 推奨 | Apple 公式の人気度、広告キャンペーンの成果 | 無料、費用は発生しません |
| **App Store Connect API** | 任意 | すべての言語のストアページの取得と公開 | 無料 |
| **OpenRouter** | 任意 | AI ライター、翻訳、ブランドと関連性のチェック、人気度の推定 | 従量課金、1 回あたり 1 セント未満 |
| **RevenueCat** | 任意 | Overview の MRR とサブスクリプション | 無料 |
| **Apple Ads ウェブセッション** | 上級 | リストにない語の Apple の正確な指数（非公開の仕組みのため自己責任） | 無料 |

キーはあなたの Mac 上の 1 つのファイルにだけ保存され、あなた以外は読めません。各キーはそれぞれのサービスにしか送られません。詳細と取得方法は **[docs/CONNECTIONS.md](docs/CONNECTIONS.md)**（英語）へ。

## 数字の仕組み

### 数字をかんたんに

| 数字 | かんたんな意味 | 良いのは |
|---|---|---|
| **Rank（順位）** | その語で検索したとき、あなたのアプリが何位に出るか。 | 小さいほど良い（#1 が最良） |
| **Popularity（人気度、5–100）** | Apple の尺度で、その語を検索する人の多さ。 | 高いほど良い |
| **Difficulty（難易度、0–100）** | 1 ページ目に入る難しさ。すでに並んでいるアプリの大きさと絞り込み具合で決まります。 | 低いほど良い |
| **Opportunity（チャンス）** | 難易度で割り引いた人気度：人気度 × (1 − (難易度 ÷ 100)²)。 | 高いほど良い |
| **Fit（関連度）** | その語で検索する人が、あなたのようなアプリを求めている確率。 | 関連あり（50% 以上） |
| **Golden ★** | 人気度 30 以上、難易度 45 以下、ブランド語ではなく、あなたのアプリに関係するもの。 | ★ |

### 人気度：まず Apple、次に推定

Apple が 1–100 の人気度を公開しているのは各ジャンルの上位語だけ（月次リスト）で、2025 年 9 月 29 日以降、それより下の語にはすべて **5** を返します。ASO Workbench は次の順で表示します。

1. **Apple のリストの値**（バッジ `Apple`、Apple Ads のキーが必要）
2. **Apple の正確な指数**（バッジ `Apple · index`、任意のウェブセッション）
3. **モデルの推定値**（バッジ `Derived · est.`）。Apple が「5」とした語には、底の語どうしを比べられるよう **6–29 の順位** を表示
4. どれもなければ **「< N」**：リストの最低値より下

推定値は、私たちが自分で学習させ、アプリに同梱しているモデルによるものです。

1. **データ。** 5 か国（US、GB、DE、FR、TR）の約 55,800 の検索語。
2. **正解ラベル。** それぞれの語に Apple の実際の人気度を付けました。
3. **手がかり。** それぞれの語を公開されている手がかりだけで表します：オートコンプリート、検索結果、そして **Jev**。Jev（TypeSafe Jev、OpenRouter 経由で使う小さな分類モデル）は「これはブランド名か？」「本当の需要がありそうか？」「どのジャンルか？」といった具体的な質問に確率で答えます。
4. **学習。** 2 つの小さな CreateML モデルが、これらの手がかりから Apple の数字を予測することを学びました。モデルはアプリに同梱されているので、あなたが学習させる必要はありません。

使うときは Jev があなたの新しい語について同じ質問に答えるため、推定には OpenRouter のキーが必要です。見たことのない語に対して Apple と同じ順に並べる相関は **0.74**、一般的な語での誤差は **約 10 ポイント** です。並べ替えの補助であり、常にラベル付きで、Apple の数字があれば必ずそちらが優先されます。**[手法の全体とテスト結果 →](docs/POPULARITY.md#the-model-step-by-step)**（英語）

### 難易度

検索する人が実際に目にする **上位 10 件** の公開結果から計算します。上位 3 件の大きさ（35%）、1 ページ目の残りの大きさ（20%）、タイトルにその語を含むアプリの数（20%）、どれだけ定着しているか（10%）、どれだけ活発に更新されているか（10%）、評価の高さ（5%）を見て、Apple が関係の薄いアプリで結果を埋めている場合は割り引きます。キーワードの詳細パネルで内訳をすべて確認できます。**[詳しく →](docs/POPULARITY.md#difficulty)**

### 変更の前と後

リリース（自動検出）、公開した変更、追加したメモは、それぞれマーカーになります。**Changes** 画面では、マーカーの前後の順位を、各キーワードの価値で重み付けして比べます。誰も検索しない語で 50 位上がっても、価値はゼロです。

## プライバシーとセキュリティ

- ローカルで動きます。ASO Workbench のサーバー、アカウント、アクセス解析はありません。
- アプリが通信するのは許可リストにあるホストだけです（Apple、OpenRouter、RevenueCat、更新確認用の GitHub）。[全リスト](SECURITY.md)を参照してください。
- あなたの確認なしに App Store Connect へ書き込むことはありません。書き込み後は必ず読み直し、審査への提出は行いません。
- キー：`~/Library/Application Support/ASO Workbench/credentials.json`（権限 600）。データ：同じフォルダの `store.sqlite`。バックアップも削除もできる普通の SQLite ファイルです。

**[SECURITY.md](SECURITY.md)** を参照してください。

## プロジェクト構成

```
Sources/
├── ASOCore/        純粋なロジック：モデル、ルール、難易度、差分、特徴量（ネットワークも画面もなし）
├── ASOProviders/   Apple、OpenRouter、RevenueCat のアダプター（許可リスト付き HTTP クライアント経由）
└── ASOWorkbench/   SwiftUI アプリ：画面、サービス、SwiftData モデル、デザインシステム
Resources/          Info.plist、アイコン、同梱の人気度モデル
scripts/            bundle-app.sh（.app をビルド）、release.sh（.dmg と GitHub リリース）
docs/               POPULARITY、CONNECTIONS、ARCHITECTURE、RELEASING
```

コンパイラが分離を保証する 3 つの層、Swift 6 の厳格な並行性、外部依存ゼロ。**[アーキテクチャ →](docs/ARCHITECTURE.md)**（英語）

## 開発

```bash
make open      # デバッグビルドして起動
make test      # ユニットテスト
make lab       # 開発者向け Lab で起動（人気度モデルの再学習）
make dist      # リリース用の .dmg と .zip を作成（メンテナー向け）
```

リリース、バージョン番号、アップデートが利用者に届く仕組み：**[docs/RELEASING.md](docs/RELEASING.md)**。コントリビュート：**[CONTRIBUTING.md](CONTRIBUTING.md)**。変更履歴：**[CHANGELOG.md](CHANGELOG.md)**。

## よくある質問

**ほかの ASO ツールと数字が違うのはなぜ？**
Apple は各ジャンルの上位より下のデータをほとんど公開していないため、ほかのツールは独自の推定で穴を埋めていますが、たいていそれを明示していません。ASO Workbench は Apple の数字があればそれを表示し、それ以外にはすべてラベルを付けます。

**Apple Ads をつなぐと費用がかかる？**
かかりません。人気度とレポートの取得は読み取り専用で、配信中のキャンペーンも不要です。

**ストアページを壊してしまうことは？**
Apply を押して確認したときにだけ書き込みます。前回の取得後にページが変わっていれば書き込みを拒否し、書き込み後は読み直し、審査には決して提出しません。

**なぜ macOS 15 が必要？**
macOS 15 を必要とする SwiftData、SwiftUI のインスペクタ、Swift 6 の機能を使っているためです。

**データはどこ？ 最初からやり直すには？**
`~/Library/Application Support/ASO Workbench/` です。アプリを終了して `store.sqlite` を削除すれば最初からやり直せます。`credentials.json` を削除するとすべてのキーが消えます。

## ライセンス

**無料で使えます。販売はできません。** Commons Clause 付きの MIT ライセンスです。ASO Workbench は無料で使え（自社の商用アプリのためにも）、コードを読んで変更し、このライセンスを添えて共有できます。本体、その改変版、主にこれを使って作った有料サービスを販売することはできません。[LICENSE](LICENSE) を参照してください。

ASO Workbench は Apple と提携しておらず、Apple の承認も受けていません。App Store、Apple Ads、App Store Connect は Apple Inc. の商標です。

<div align="center"><sub><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <b>日本語</b> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a></sub></div>
