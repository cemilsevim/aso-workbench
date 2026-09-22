<div align="center">

<img src="docs/media/icon.png" width="128" height="128" alt="ASO Workbench 아이콘">

# ASO Workbench

**Mac에서 하는 App Store 최적화, 숫자는 언제나 정직하게.**
앱 순위를 추적하고, 실제로 이길 수 있는 키워드를 찾고, 모든 언어로 스토어 페이지를 작성해 게시하고, 변경할 때마다 그 효과를 확인하세요.

[![다운로드](https://img.shields.io/github/v/release/mustafakendiguzel/aso-workbench?label=download&style=flat-square&color=brightgreen)](https://github.com/mustafakendiguzel/aso-workbench/releases/latest)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue?style=flat-square)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange?style=flat-square)
[![라이선스](https://img.shields.io/badge/license-MIT%20%2B%20Commons%20Clause-lightgrey?style=flat-square)](LICENSE)

[설치](#설치) · [빠른 시작](#빠른-시작) · [기능](#기능) · [연결과 키](#연결과-키) · [숫자는 어떻게 계산되나](#숫자는-어떻게-계산되나) · [자주 묻는 질문](#자주-묻는-질문)

<sub><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <b>한국어</b> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a></sub>

</div>

<div align="center">
  <a href="docs/media/demo.mp4"><img src="docs/media/demo.gif" width="880" alt="ASO Workbench 사용 모습"></a>
  <br>
  <sub>▶ <a href="docs/media/demo.mp4"><b>전체 데모 보기</b></a> · 위 미리보기는 소리 없이 반복 재생됩니다</sub>
</div>

---

> 앱 화면은 영어입니다. 아래의 버튼과 메뉴 이름은 앱에 표시되는 그대로 적었습니다.

## 왜 ASO Workbench인가

대부분의 ASO 도구는 키워드마다 확신에 찬 숫자 하나를 보여 줍니다. 그 숫자는 대개 추측이며, 어디까지가 Apple의 데이터이고 어디부터가 도구의 추측인지 아무도 알려 주지 않습니다.

ASO Workbench는 다른 길을 택했습니다.

- **모든 숫자에 출처가 표시됩니다.** Apple 공식 인기도, 공개 검색 측정값, 모델 추정값은 서로 다른 배지를 달고 절대 섞이지 않습니다.
- **"찾지 못함"은 "201위"가 아닙니다.** 없음, 요청 실패, "확인 안 함"을 따로 기록합니다.
- **내 Mac에서 실행됩니다.** 계정도, 서버도, 원격 수집도 없습니다. 키는 내 Mac의 파일 하나에만 저장됩니다.
- **키 없이도 동작하며**, 키를 하나 추가할 때마다 할 수 있는 일이 늘어납니다.

## 기능

| | |
|---|---|
| 📈 **추적** | 키워드별 순위를 국가와 기기별로, 실제 App Store 검색(상위 200개)에서 가져옵니다. 출시 시점이 표시된 기록 그래프. Δ는 직전 출시를 기준으로 하므로 다시 측정해도 상승폭이 사라지지 않습니다. 국가별 평점 수와 작성된 리뷰. |
| 🔎 **리서치** | Apple이 공개하는 곳에서는 Apple의 인기도, 나머지는 표시가 붙은 추정값. 상위 10개 결과로 계산하고 내역까지 설명되는 난이도. **골든 키워드**(실제 수요, 이길 수 있는 경쟁, 다른 회사의 브랜드가 아님, 내 앱과 관련 있음). 경쟁 앱 키워드 가져오기. 자동 완성 아이디어. |
| 🌍 **세계로** | 내 키워드를 다른 나라들에서 한 번에 시험해 보세요. AI가 제안하는 현지어 검색 표현까지 포함되며, 좋은 결과는 클릭 한 번으로 추적을 시작합니다. |
| ✍️ **작성** | 이길 수 있는 키워드부터 제목, 부제목, 키워드 필드를 채우는 AI 작성기. *Make better*가 모든 규칙 위반을 고칩니다. 모든 언어를 한 번에 작성, 모든 언어의 What's New, 이용 약관과 개인정보 처리방침 링크 자동 추가. |
| 🚀 **게시** | 초안을 App Store Connect로 보냅니다. 빠진 언어를 만들고, 스크린샷을 복사하고, 다음 버전을 만들며, 쓸 때마다 다시 읽어 확인합니다. 심사에 제출하지는 않습니다. |
| 🧪 **측정** | 출시와 변경의 타임라인, 키워드 가치로 가중한 전후 비교 리포트. 키워드별, 국가별 Apple Ads 성과. RevenueCat의 MRR과 구독 정보. |

## 설치

### 다운로드 (가장 쉬운 방법)

1. [최신 릴리스](https://github.com/mustafakendiguzel/aso-workbench/releases/latest)에서 **`ASO-Workbench-x.y.z.dmg`** 를 내려받습니다.
2. 열어서 **ASO Workbench** 를 **Applications**(응용 프로그램)로 드래그합니다.
3. 처음 열 때 macOS가 개발자를 확인할 수 없다고 알립니다(앱은 무료이며 공증을 받지 않았습니다). 앱을 오른쪽 클릭 → **열기** → **열기**. 또는 시스템 설정 → 개인정보 보호 및 보안 → **그래도 열기**.

새 버전이 나오면 앱이 알려 줍니다(사이드바 아래쪽, 또는 **ASO Workbench ▸ Check for Updates…**). 새 버전이 데이터를 처음 열기 전에 데이터는 자동으로 백업됩니다.

### 소스에서 빌드

macOS 15 이상과 Xcode 26(Swift 6.2)이 필요합니다. 외부 의존성은 없습니다.

```bash
git clone https://github.com/mustafakendiguzel/aso-workbench.git
cd aso-workbench
make install        # 최적화 빌드 → /Applications/ASO Workbench.app
```

이후에는 `make update` 로 최신 코드를 받아 다시 설치합니다. `make help` 는 모든 명령을 보여 줍니다.

## 빠른 시작

1. **Add App**(사이드바 아래쪽) → App Store 링크를 붙여 넣습니다. 카테고리는 자동으로 채워집니다.
2. **Keywords** → **Add** → 관심 있는 키워드를 한 줄에 하나씩 입력합니다.
3. **Update ▸ Measure all** → 순위가 키워드별로 들어옵니다(하나에 약 3초. Apple이 공개 검색 빈도를 제한합니다).
4. 선택: **Connections** → Apple Ads 키 추가 → **Update ▸ Refresh popularity**. 이제 Apple 공식 인기도를 볼 수 있습니다.
5. Filters ▸ **Golden** 은 노려 볼 만한 키워드를 보여 줍니다. **Metadata ▸ Write** 가 그 키워드로 스토어 페이지를 작성합니다.

## 연결과 키

시작하는 데 키는 필요 없습니다. 키마다 특정 기능이 열립니다. 앱의 **Connections** 화면에서 하나씩 단계별로 설명합니다.

| 연결 | 필요 여부 | 가능해지는 것 | 비용 |
|---|---|---|---|
| *(없음)* | 필요 없음 | 순위, 자동 완성, 경쟁 앱, 난이도, 평점, 리뷰 | 무료 |
| **Apple Ads API** | 권장 | Apple 공식 인기도, 광고 캠페인 성과 | 무료, 비용 발생 없음 |
| **App Store Connect API** | 선택 | 모든 언어의 스토어 페이지 가져오기와 게시 | 무료 |
| **OpenRouter** | 선택 | AI 작성기, 번역, 브랜드와 관련성 검사, 인기도 추정 | 사용한 만큼 지불, 1회 1센트 미만 |
| **RevenueCat** | 선택 | Overview의 MRR과 구독 정보 | 무료 |
| **Apple Ads 웹 세션** | 고급 | 목록에 없는 단어에 대한 Apple의 정확한 지수(비공개 방식, 사용자 책임) | 무료 |

키는 내 Mac의 파일 하나에만 저장되고 나만 읽을 수 있으며, 각 키는 자기 서비스로만 전송됩니다. 자세한 내용과 발급 방법은 **[docs/CONNECTIONS.md](docs/CONNECTIONS.md)**(영어)를 보세요.

## 숫자는 어떻게 계산되나

### 숫자를 쉽게 설명하면

| 숫자 | 쉬운 뜻 | 좋은 쪽 |
|---|---|---|
| **Rank(순위)** | 누군가 이 단어를 검색했을 때 내 앱이 몇 번째로 나오는지. | 낮을수록 좋음(#1이 최고) |
| **Popularity(인기도, 5–100)** | Apple 기준으로 이 단어를 검색하는 사람이 얼마나 많은지. | 높을수록 좋음 |
| **Difficulty(난이도, 0–100)** | 첫 페이지에 오르기가 얼마나 어려운지. 이미 그 자리에 있는 앱들이 얼마나 크고 집중되어 있는지로 판단합니다. | 낮을수록 좋음 |
| **Opportunity(기회)** | 난이도로 할인한 인기도: 인기도 × (1 − (난이도 ÷ 100)²). | 높을수록 좋음 |
| **Fit(관련도)** | 이 단어를 검색하는 사람이 내 앱 같은 앱을 원할 가능성. | 관련 있음(50% 이상) |
| **Golden ★** | 인기도 30 이상, 난이도 45 이하, 브랜드가 아니며 내 앱과 관련 있음. | ★ |

### 인기도: 먼저 Apple, 그다음 추정

Apple은 각 장르의 상위 단어에 대해서만 1–100 인기도를 공개하며(월간 목록), 2025년 9월 29일부터는 그 아래의 모든 단어에 **5** 를 반환합니다. ASO Workbench는 다음 순서로 보여 줍니다.

1. **Apple 목록 값**(배지 `Apple`, Apple Ads 키 필요)
2. **Apple 정확한 지수**(배지 `Apple · index`, 선택 사항인 웹 세션)
3. **모델 추정값**(배지 `Derived · est.`). Apple이 "5"라고 한 단어에는 서로 비교할 수 있도록 바닥 단어 사이의 **6–29 순위** 를 표시
4. 그 밖에는 **"< N"**: 목록의 최저 점수보다 낮음

추정값은 저희가 직접 학습시켜 앱에 넣은 모델에서 나옵니다.

1. **데이터.** 5개 국가(US, GB, DE, FR, TR)의 검색어 약 55,800개.
2. **정답.** 각 검색어에 Apple의 실제 인기도를 붙였습니다.
3. **단서.** 각 검색어는 공개된 단서로만 설명합니다: 자동 완성, 검색 결과, 그리고 **Jev**. Jev(TypeSafe Jev, OpenRouter를 통해 쓰는 작은 분류 모델)는 "브랜드인가?", "실제 수요처럼 보이는가?", "어느 장르인가?" 같은 구체적인 질문에 확률로 답합니다.
4. **학습.** 두 개의 작은 CreateML 모델이 이 단서들로 Apple의 숫자를 예측하도록 학습했습니다. 모델은 앱에 들어 있으므로 직접 학습시킬 필요가 없습니다.

사용할 때는 Jev가 새 검색어에 대해 같은 질문에 답하므로, 추정에는 OpenRouter 키가 필요합니다. 처음 보는 단어에서 Apple과 같은 순서로 정렬하는 상관계수는 **0.74**, 일반적인 단어의 오차는 **약 10점** 입니다. 정렬을 돕는 도구이며 항상 표시가 붙고, Apple의 숫자가 있으면 언제나 그것이 우선합니다. **[전체 방법과 테스트 결과 →](docs/POPULARITY.md#the-model-step-by-step)**(영어)

### 난이도

검색하는 사람이 실제로 보는 **상위 10개** 공개 결과로 계산합니다. 상위 3개의 규모(35%), 첫 페이지 나머지의 규모(20%), 제목에 그 단어가 들어간 앱의 수(20%), 얼마나 자리 잡았는지(10%), 얼마나 활발히 업데이트되는지(10%), 평점이 얼마나 좋은지(5%)를 보고, Apple이 관련 없는 앱으로 결과를 채우는 경우에는 할인합니다. 키워드 상세 패널에서 모든 항목을 볼 수 있습니다. **[자세히 →](docs/POPULARITY.md#difficulty)**

### 변경 전후

모든 출시(자동 감지), 게시한 모든 변경, 추가한 모든 메모가 표시가 됩니다. **Changes** 화면은 표시 전후의 순위를 각 키워드의 가치로 가중해 비교합니다. 아무도 검색하지 않는 단어에서 50계단 오르는 것은 아무 가치가 없습니다.

## 개인정보와 보안

- 로컬에서 실행됩니다. ASO Workbench 서버, 계정, 분석 도구가 없습니다.
- 앱은 허용 목록에 있는 호스트와만 통신합니다(Apple, OpenRouter, RevenueCat, 업데이트 확인용 GitHub). [전체 목록](SECURITY.md)을 참고하세요.
- 사용자의 확인 없이는 App Store Connect에 아무것도 쓰지 않습니다. 쓴 뒤에는 다시 읽어 확인하며, 심사에 제출하지 않습니다.
- 키: `~/Library/Application Support/ASO Workbench/credentials.json`(권한 600). 데이터: 같은 폴더의 `store.sqlite`, 백업하거나 지울 수 있는 일반 SQLite 파일입니다.

**[SECURITY.md](SECURITY.md)** 를 참고하세요.

## 프로젝트 구조

```
Sources/
├── ASOCore/        순수 로직: 모델, 규칙, 난이도, 차이 비교, 특징(네트워크와 화면 없음)
├── ASOProviders/   Apple, OpenRouter, RevenueCat 어댑터(허용 목록이 있는 HTTP 클라이언트 뒤)
└── ASOWorkbench/   SwiftUI 앱: 화면, 서비스, SwiftData 모델, 디자인 시스템
Resources/          Info.plist, 아이콘, 내장 인기도 모델
scripts/            bundle-app.sh(.app 빌드), release.sh(.dmg와 GitHub 릴리스)
docs/               POPULARITY, CONNECTIONS, ARCHITECTURE, RELEASING
```

컴파일러가 분리를 보장하는 세 개의 층, Swift 6 엄격한 동시성, 외부 의존성 없음. **[아키텍처 →](docs/ARCHITECTURE.md)**(영어)

## 개발

```bash
make open      # 디버그 빌드 후 실행
make test      # 단위 테스트
make lab       # 개발자용 Lab으로 실행(인기도 모델 재학습)
make dist      # 릴리스용 .dmg와 .zip 만들기(관리자용)
```

릴리스, 버전 번호, 업데이트가 사용자에게 전달되는 방식: **[docs/RELEASING.md](docs/RELEASING.md)**. 기여: **[CONTRIBUTING.md](CONTRIBUTING.md)**. 변경 기록: **[CHANGELOG.md](CHANGELOG.md)**.

## 자주 묻는 질문

**다른 ASO 도구와 숫자가 다른 이유는?**
Apple은 각 장르 상위 아래의 데이터를 거의 공개하지 않기 때문에, 다른 도구들은 자체 추정으로 빈칸을 채우고 대개 그 사실을 밝히지 않습니다. ASO Workbench는 Apple의 숫자가 있으면 그것을 보여 주고, 나머지에는 모두 표시를 붙입니다.

**Apple Ads를 연결하면 비용이 드나요?**
아니요. 인기도와 리포트 조회는 읽기 전용이며 진행 중인 캠페인도 필요 없습니다.

**제 스토어 페이지를 망가뜨릴 수 있나요?**
Apply를 누르고 확인했을 때만 씁니다. 마지막으로 가져온 뒤 페이지가 바뀌었으면 쓰기를 거부하고, 쓴 뒤에는 다시 읽으며, 심사에는 절대 제출하지 않습니다.

**왜 macOS 15가 필요한가요?**
macOS 15가 필요한 SwiftData, SwiftUI 인스펙터, Swift 6 기능을 사용하기 때문입니다.

**데이터는 어디에 있나요? 처음부터 다시 하려면?**
`~/Library/Application Support/ASO Workbench/` 입니다. 앱을 종료하고 `store.sqlite` 를 지우면 처음부터 시작합니다. `credentials.json` 을 지우면 모든 키가 삭제됩니다.

## 라이선스

**무료로 사용할 수 있고, 판매는 할 수 없습니다.** Commons Clause가 붙은 MIT 라이선스입니다. ASO Workbench를 무료로 사용할 수 있고(자신의 상업용 앱을 위해서도), 코드를 읽고 수정하며, 이 라이선스를 함께 붙여 공유할 수 있습니다. 이 소프트웨어, 수정본, 주로 이를 바탕으로 만든 유료 서비스를 판매할 수는 없습니다. [LICENSE](LICENSE)를 참고하세요.

ASO Workbench는 Apple과 제휴하거나 Apple의 승인을 받지 않았습니다. App Store, Apple Ads, App Store Connect는 Apple Inc.의 상표입니다.

<div align="center"><sub><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <b>한국어</b> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a></sub></div>
