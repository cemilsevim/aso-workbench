# How ASO Workbench measures popularity (and difficulty)

> **In one sentence:** popularity is *how many people search a phrase*, difficulty is *how hard it is to reach page one for it*. ASO Workbench takes popularity from Apple wherever Apple publishes it, and only fills the gaps with a model it labels as an estimate.

- [Why this is harder than it sounds](#why-this-is-harder-than-it-sounds)
- [The four layers](#the-four-layers)
- [The model, step by step](#the-model-step-by-step)
- [How good is it?](#how-good-is-it)
- [The 6–29 band](#the-629-band)
- [Difficulty](#difficulty)
- [Opportunity, Golden and value](#opportunity-golden-and-value)
- [Retraining the model](#retraining-the-model)

---

## Why this is harder than it sounds

Apple is the only party that knows how often a phrase is searched. It shares a **1–100 "Search Popularity"** score through Apple Ads — but not for everything:

1. **The monthly lists stop at the top.** Apple's *Search Term Rank* report lists roughly the top 500 terms per genre and country. The lowest score on those lists is usually around 40–50.
2. **Below that, everything is 5.** Since 29 September 2025 Apple reports **5** for every term below its published range. In the US the number of terms scoring above 5 fell by about three quarters in four days. So in Apple's own numbers there is nothing between 6 and ~31: a term is either "5" or "32 and up".
3. **Suggestion scores are not popularity.** Apple Ads keyword suggestions come with a "relative popularity", but the same term gets different numbers depending on the seed you ask with (we measured "comic" at 5, 25, 26 and 30 from four seeds). ASO Workbench does not use them as popularity.

So an honest tool has to say *"Apple says 5"* for most long-tail terms. ASO Workbench does that, and adds a clearly labelled model estimate so you can still order those terms.

## The four layers

Every popularity cell tells you where its number came from (hover it for the details):

| Layer | Badge | Source | Needs |
|---|---|---|---|
| 1. Country list | `Apple` + genre | Apple Ads *Search Term Rank* lists, last full month, per country and genre | Apple Ads API key |
| 2. Exact index | `Apple` · index | The popularity index the Apple Ads website shows for any exact term | Signing in to the Apple Ads website inside the app (optional, undocumented) |
| 3. Model estimate | `Derived` · est. | The bundled model, from public signals | OpenRouter key (for the Jev features) |
| 4. Upper bound | `< N` | "Not on any list, so below the lowest listed score N" | nothing |

When Apple's answer is the floor (5), the cell shows the **model's 6–29 value** instead, marked `model · Apple 5`, so floor terms can be compared with each other (see [The 6–29 band](#the-629-band)).

## The model, step by step

Think of it as teaching a student to guess popularity by looking at the same clues a human would, and grading the student against Apple's real answers.

### 1. Collect terms (the "universe")

About 55,800 terms across five storefronts (US, GB, DE, FR, TR), from three places:

- Apple's genre lists (15 genres × ~500 terms per country) — they come *with* Apple's score;
- Apple Ads keyword suggestions seeded with real apps — mostly long-tail terms;
- App Store autocomplete, expanded from seeds — what people start typing.

### 2. Label them with Apple's answer

- Terms from the lists keep Apple's list score.
- Everything else is looked up in the Apple Ads website index (5 or 32–93).

These labels are the "answer key". About two thirds of the terms are in Apple's published range (all list terms, and roughly one in ten looked-up terms); the rest are at the floor.

### 3. Describe each term with public clues (features)

| Group | Clues |
|---|---|
| Lexical | words, characters, average word length, digits, non-Latin letters, punctuation |
| Autocomplete | how many suggestions Apple autocomplete returns for the term, its first word and its first four letters, and at which position the term itself appears |
| Search results | how many apps come back, the leader's and the top ten's rating counts, how many name the term, how many different sellers |
| Jev | a small classification model (TypeSafe Jev, via OpenRouter) answers narrow questions with probabilities: is it a brand, a natural search, in the store's language, a head term or long tail, how much demand it sounds like, and which genre it belongs to |

No clue uses Apple's popularity, so the model can run on any term in any country.

### 4. Train two small models (CreateML boosted trees)

1. **Classifier:** *is this term in Apple's published range (≥ 30)?* — the most important question, because most terms are not.
2. **Regressor:** *if it is, what number?* — trained only on published-range terms.

At run time a value is shown only when the classifier is at least 65% sure; otherwise the cell says the term is below the range.

### 5. Ship them

The two models are compiled into the app (`Resources/models/*.mlmodel`, about 2 MB). Nobody has to train anything; every user gets the same estimates.

## How good is it?

Measured on terms the model never saw during training (model of 19 September 2026, 44,658 training rows):

| Test | Rank agreement (Spearman) | Mean error | Within one band |
|---|---|---|---|
| Terms with autocomplete clues — what the app sees in real use (578 held out) | **0.74** | **10.4 points** | 81% |
| Random 20% of all terms | 0.45 | 15.6 | 75% |
| A whole country the model never saw (TR) | 0.37 | 17.2 | 71% |
| A whole topic the model never saw (Games / Productivity / Health) | 0.27–0.35 | 20–30 | 44–63% |

"Is it in the published range?" is answered correctly 75–81% of the time (precision 0.78, recall 0.88).

**What this means for you:** the estimate is good for *ordering* terms and separating "some demand" from "none", and it is off by around ten points on a typical term. It is weaker in countries and topics it has not seen. That is why it is always labelled `est.`, and why Apple's own number always wins when there is one. The most useful features are Jev's language-fit, demand and brand answers.

## The 6–29 band

Apple's floor (5) covers most of the long tail. To order those terms, ASO Workbench takes the classifier's probability that a term has published-range demand and places it among the floor terms of the test set, in 24 equal slots:

- **6** — weaker than almost every floor term;
- **18** — about the middle of floor terms;
- **29** — stronger than almost every floor term (close to being published).

It is a **rank among floor terms**, not an Apple number, and it never goes above 29 — Apple owns 30 and up.

## Difficulty

Difficulty answers *"how hard is page one for this term?"* from the **top ten public search results** (what a searcher actually sees). Six questions, each scored 0–100:

| Component | Weight | Question |
|---|---|---|
| Incumbent strength | 35% | How big are the top three apps? (rating counts, position-weighted, 1M ratings = 100) |
| Field depth | 20% | Is the rest of page one big too? (median rating count, 100k = 100) |
| Keyword targeting | 20% | Do the top ten name the term in their title? |
| Maturity | 10% | How long have they been around? (four years = 100) |
| Activity | 10% | Were they updated in the last 60 days? |
| Satisfaction | 5% | Are their users happy? (3★ = 0, 5★ = 100) |

Then two corrections: if few of the top ten mention the term at all, Apple is padding the page with loosely related apps and the score is discounted (down to ×0.6); a page with fewer than ten results is discounted too. Finally the sum is mapped onto a calibrated curve so the tiers mean the same everywhere:

| Score | Tier |
|---|---|
| ≤ 15 | Very easy |
| ≤ 35 | Easy |
| ≤ 55 | Moderate |
| ≤ 75 | Hard |
| ≤ 90 | Very hard |
| > 90 | Extreme |

Difficulty is an estimate of competition, **not** a probability of ranking. The keyword inspector shows every component.

## Opportunity, Golden and value

- **Opportunity** = popularity × (1 − (difficulty ÷ 100)²). Demand, discounted more and more steeply as competition rises.
- **Golden** = Apple popularity ≥ 30, difficulty ≤ 45 (both adjustable in Settings), not another company's brand (by Jev *and* by the search results), and related to what your app does (Jev "fit" ≥ 50%).
- **Value** (used in before/after reports) = popularity × (1 − (difficulty ÷ 100)²) × fit, zero for brands and unrelated terms. Rising 50 places on a term nobody searches is worth nothing; rising 5 places on a valuable one is worth a lot.

## Retraining the model

Only needed if you want to extend the model (more countries, fresher labels). Normal use never requires it.

1. `make lab` — builds the app and launches it with the developer **Lab** (a *Popularity model* item appears in the sidebar and `asoworkbench://lab/…` URL commands are accepted). Without `ASO_LAB=1` the Lab is hidden and URL commands are ignored.
2. Connect Apple Ads, sign in to the Apple Ads website session and add an OpenRouter key.
3. In the Lab: choose storefronts → **Run everything** (universe → labels → autocomplete → search results → Jev → train). Every stage resumes where it stopped; Apple's autocomplete throttles bursts, so the autocomplete stage is the slow one.
4. The report shows the tables above. If it is better than the shipped one, copy `~/Library/Application Support/ASO Workbench/models/*.mlmodel` and `report.json` into `Resources/models/` and rebuild (`make bundle`).

The Lab's data (`TrainingRow` records) lives in your local data file and is never shipped.
