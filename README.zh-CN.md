<div align="center">

<img src="docs/media/icon.png" width="128" height="128" alt="ASO Workbench 图标">

# ASO Workbench

**在你的 Mac 上做 App Store 优化，数字诚实可靠。**
追踪你的 App 在每个关键词下的排名，找到真正能赢的关键词，用每种语言撰写并发布商店页面，并看清每次改动带来的效果。

[![下载](https://img.shields.io/github/v/release/mustafakendiguzel/aso-workbench?label=%E4%B8%8B%E8%BD%BD&style=flat-square&color=brightgreen)](https://github.com/mustafakendiguzel/aso-workbench/releases/latest)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue?style=flat-square)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange?style=flat-square)
[![许可证](https://img.shields.io/badge/license-MIT%20%2B%20Commons%20Clause-lightgrey?style=flat-square)](LICENSE)

[安装](#安装) · [快速开始](#快速开始) · [功能](#功能) · [连接与密钥](#连接与密钥) · [数字如何计算](#数字如何计算) · [常见问题](#常见问题)

<sub><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <b>简体中文</b> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a></sub>

</div>

<div align="center">
  <a href="docs/media/demo.mp4"><img src="docs/media/demo.gif" width="880" alt="ASO Workbench 使用演示"></a>
  <br>
  <sub>▶ <a href="docs/media/demo.mp4"><b>观看完整演示</b></a> · 上方预览为静音循环播放</sub>
</div>

---

> App 的界面语言为英文。下文中的按钮和菜单名称与 App 中保持一致。

## 为什么选择 ASO Workbench

大多数 ASO 工具会给每个关键词一个看起来很确定的数字。这个数字往往只是猜测，而且没人告诉你哪部分来自 Apple，哪部分来自工具本身。

ASO Workbench 走了另一条路：

- **每个数字都标明来源。** Apple 官方热度、公开搜索的测量值和模型估算带有不同的标记，绝不混在一起。
- **“没找到”不等于“第 201 名”。** 不存在、请求失败和“未检查”分开记录。
- **完全在你的 Mac 上运行。** 没有账号，没有服务器，没有遥测。你的密钥只保存在本机的一个文件里。
- **不需要任何密钥也能用**，每添加一个密钥就多解锁一项能力。

## 功能

| | |
|---|---|
| 📈 **追踪** | 每个关键词的排名，按国家和设备区分，来自真实的 App Store 搜索（前 200 名）。历史图表上标出你的每次发布。Δ 以上一次发布为基准，重新测量时进步不会消失。各国家的评分数量和文字评论。 |
| 🔎 **研究** | Apple 公开热度的地方直接用 Apple 的数字，其他地方显示带标记的估算。基于前十个结果、完全可解释的难度。**黄金关键词**（真实需求、可以超越的竞争、不是别人的品牌、与你的 App 相关）。导入竞品的关键词。自动补全灵感。 |
| 🌍 **走向全球** | 一次性在其他国家试用你的关键词，包括 AI 建议的当地语言搜索写法，一键追踪表现好的词。 |
| ✍️ **撰写** | AI 撰写器会优先把你能赢的关键词放进标题、副标题和关键词字段。*Make better* 修复每一条规则问题。一次写完所有语言，为所有语言生成 What's New，自动添加使用条款和隐私政策链接。 |
| 🚀 **发布** | 把草稿发送到 App Store Connect：自动创建缺失的语言、复制截图、创建下一个版本，每次写入后都会回读确认。不会提交审核。 |
| 🧪 **衡量** | 发布与改动的时间线，并按关键词价值加权的前后对比报告。你的 Apple Ads 各关键词、各国家的投放结果。来自 RevenueCat 的 MRR 和订阅数据。 |

## 安装

### 下载（最简单）

1. 从[最新版本](https://github.com/mustafakendiguzel/aso-workbench/releases/latest)下载 **`ASO-Workbench-x.y.z.dmg`**。
2. 打开后把 **ASO Workbench** 拖到 **Applications**（应用程序）。
3. 第一次打开时，macOS 会提示无法验证开发者（App 免费且未经公证）。右键点击 App → **打开** → **打开**。或者：系统设置 → 隐私与安全性 → **仍要打开**。

有新版本时，App 会提醒你（侧边栏底部，或 **ASO Workbench ▸ Check for Updates…**）。新版本首次打开数据前会自动备份。

### 从源码构建

需要 macOS 15+ 和 Xcode 26（Swift 6.2）。没有第三方依赖。

```bash
git clone https://github.com/mustafakendiguzel/aso-workbench.git
cd aso-workbench
make install        # 优化构建 → /Applications/ASO Workbench.app
```

之后：`make update` 拉取最新代码并重新安装。`make help` 列出所有命令。

## 快速开始

1. **Add App**（侧边栏底部）→ 粘贴你的 App Store 链接。类别会自动填好。
2. **Keywords** → **Add** → 输入你关心的关键词，每行一个。
3. **Update ▸ Measure all** → 排名逐个出现（每个约 3 秒，Apple 限制了公开搜索的频率）。
4. 可选：**Connections** → 添加 Apple Ads 密钥 → **Update ▸ Refresh popularity**。现在你能看到 Apple 官方的热度了。
5. Filters ▸ **Golden** 显示值得争取的关键词。**Metadata ▸ Write** 把它们写成商店页面。

## 连接与密钥

开始使用不需要任何密钥。每个密钥解锁一项具体能力；App 里的 **Connections** 页面会逐一说明，并给出分步指引。

| 连接 | 是否需要 | 解锁 | 费用 |
|---|---|---|---|
| *（无）* | 不需要 | 排名、自动补全、竞品、难度、评分、评论 | 免费 |
| **Apple Ads API** | 推荐 | Apple 官方热度、你的广告投放结果 | 免费，不产生花费 |
| **App Store Connect API** | 可选 | 以每种语言拉取和发布你的商店页面 | 免费 |
| **OpenRouter** | 可选 | AI 撰写、翻译、品牌与相关性检查、热度估算 | 按量付费，每次不到一美分 |
| **RevenueCat** | 可选 | Overview 页面上的 MRR 和订阅数据 | 免费 |
| **Apple Ads 网站会话** | 高级 | 对不在榜单上的词读取 Apple 的精确指数（非公开接口，风险自负） | 免费 |

密钥只保存在你 Mac 上的一个文件里，只有你能读取，每个密钥只发往它自己的服务。详情及获取方式见 **[docs/CONNECTIONS.md](docs/CONNECTIONS.md)**（英文）。

## 数字如何计算

### 数字的通俗解释

| 数字 | 通俗含义 | 越…越好 |
|---|---|---|
| **Rank（排名）** | 有人搜索这个词时，你的 App 排在第几位。 | 越小越好（#1 最好） |
| **Popularity（热度，5–100）** | 按 Apple 的标尺，有多少人搜索这个词。 | 越高越好 |
| **Difficulty（难度，0–100）** | 进入第一页有多难，取决于已经在那里的 App 有多大、多专注。 | 越低越好 |
| **Opportunity（机会）** | 按难度折算后的热度：热度 × (1 − (难度 ÷ 100)²)。 | 越高越好 |
| **Fit（相关度）** | 搜索这个词的人想要一个像你这样的 App 的可能性。 | 相关（≥ 50%） |
| **Golden ★（黄金）** | 热度 ≥ 30，难度 ≤ 45，不是品牌词，与你的 App 相关。 | ★ |

### 热度：先看 Apple，再看估算

Apple 只为每个类别的头部词公开 1–100 的热度（每月榜单），并且自 2025 年 9 月 29 日起，对其下的所有词都报告 **5**。ASO Workbench 依次显示：

1. **Apple 榜单值**（标记 `Apple`，需要 Apple Ads 密钥），
2. **Apple 精确指数**（标记 `Apple · index`，可选的网站会话），
3. **模型估算**（标记 `Derived · est.`）；对于 Apple 给出 “5” 的词，显示其在底部词中的 **6–29 排序**，方便互相比较，
4. 否则显示 **“< N”**：低于榜单中的最低分。

估算来自我们自己训练、随 App 一起提供的模型：

1. **数据。** 来自五个国家（US、GB、DE、FR、TR）的约 55,800 个搜索词。
2. **标准答案。** 每个词都标注了 Apple 的真实热度。
3. **线索。** 每个词只用公开线索来描述：自动补全、搜索结果和 **Jev**。Jev（TypeSafe Jev，通过 OpenRouter 调用的小型分类模型）以概率回答具体的问题，例如“这是品牌吗？”“听起来像真实需求吗？”“属于哪个类别？”。
4. **训练。** 两个小型 CreateML 模型学会了根据这些线索预测 Apple 的数字。模型随 App 一起提供，你不需要训练任何东西。

使用时，Jev 会为你的新词回答同样的问题，因此估算需要 OpenRouter 密钥。在从未见过的词上，模型给出的顺序与 Apple 的相关系数为 **0.74**，一般偏差约 **10 分**。它是排序的辅助，始终带有标记，只要 Apple 有数字就以 Apple 为准。**[完整方法与测试结果 →](docs/POPULARITY.md#the-model-step-by-step)**（英文）

### 难度

基于搜索者真正看到的**前十个**公开结果计算。它衡量前三名有多大（35%）、第一页其余的有多大（20%）、有多少在标题中包含该关键词（20%）、它们有多成熟（10%）、更新有多频繁（10%）以及评分有多高（5%）；当 Apple 用不相关的 App 填充页面时会打折扣。关键词详情面板会显示每一部分。**[详情 →](docs/POPULARITY.md#difficulty)**

### 改动前后对比

每次发布（自动识别）、你发布的每个改动和你添加的每条备注都会成为一个标记。**Changes** 页面按每个关键词的价值加权，比较标记前后的排名。在没人搜索的词上前进 50 名，价值为零。

## 隐私与安全

- 完全在本地运行。没有 ASO Workbench 服务器、没有账号、没有统计分析。
- App 只与允许列表中的主机通信（Apple、OpenRouter、RevenueCat，以及用于检查更新的 GitHub）。见[完整列表](SECURITY.md)。
- 未经你确认，不会向 App Store Connect 写入任何内容；每次写入后都会回读；不会提交审核。
- 密钥：`~/Library/Application Support/ASO Workbench/credentials.json`（权限 600）。数据：同一文件夹中的 `store.sqlite`，一个可以备份或删除的普通 SQLite 文件。

见 **[SECURITY.md](SECURITY.md)**。

## 项目结构

```
Sources/
├── ASOCore/        纯逻辑：模型、规则、难度、差异、特征（无网络、无界面）
├── ASOProviders/   Apple、OpenRouter 和 RevenueCat 适配器，位于带允许列表的 HTTP 客户端之后
└── ASOWorkbench/   SwiftUI App：界面、服务、SwiftData 模型、设计系统
Resources/          Info.plist、图标、内置热度模型
scripts/            bundle-app.sh（构建 .app）、release.sh（.dmg + GitHub 版本）
docs/               POPULARITY、CONNECTIONS、ARCHITECTURE、RELEASING
```

编译器强制分离的三层结构，Swift 6 严格并发，零依赖。**[架构 →](docs/ARCHITECTURE.md)**（英文）

## 开发

```bash
make open      # 调试构建并启动
make test      # 单元测试
make lab       # 以开发者 Lab 模式启动（重新训练热度模型）
make dist      # 为发布构建 .dmg 和 .zip（维护者）
```

版本发布、版本号以及更新如何送达用户：**[docs/RELEASING.md](docs/RELEASING.md)**。参与贡献：**[CONTRIBUTING.md](CONTRIBUTING.md)**。更新记录：**[CHANGELOG.md](CHANGELOG.md)**。

## 常见问题

**为什么我的数字和其他 ASO 工具不一样？**
因为 Apple 在每个类别头部以下公开的数据很少，其他工具会用自己的估算填补空白，而且通常不说明。ASO Workbench 在 Apple 有数字时显示 Apple 的数字，其余一律加上标记。

**连接 Apple Ads 会花钱吗？**
不会。热度和报告接口都是只读的，也不需要正在投放的广告。

**它会弄坏我的 App Store 页面吗？**
只有在你点击 Apply 并确认后才会写入；如果页面在你上次拉取后被改过，它会拒绝写入；写入后会回读，并且从不提交审核。

**为什么需要 macOS 15？**
它使用了需要 macOS 15 的 SwiftData、SwiftUI inspector 和 Swift 6 特性。

**我的数据在哪里？如何从头开始？**
`~/Library/Application Support/ASO Workbench/`。退出 App 并删除 `store.sqlite` 即可从头开始；删除 `credentials.json` 即可移除所有密钥。

## 许可证

**可以免费使用，不可以出售。** 采用附加 Commons Clause 的 MIT 许可证：你可以免费使用 ASO Workbench（包括用于你自己的商业 App），阅读和修改代码，并在附带本许可证的前提下分享。你不能出售它、它的修改版本，或主要基于它构建的付费服务。见 [LICENSE](LICENSE)。

ASO Workbench 与 Apple 没有关联，也未获得 Apple 认可。App Store、Apple Ads 和 App Store Connect 是 Apple Inc. 的商标。

<div align="center"><sub><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <b>简体中文</b> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a></sub></div>
