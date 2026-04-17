---
name: apple-app-market-scan
description: >
  Two modes:
  (1) With keyword: scan App Store rankings, Product Hunt launches, and
  web sources for a specific Apple app category. Produces a facts-only
  market report to .research/apple-app/.
  (2) Without keyword: broad discovery across App Store categories to
  identify underserved niches, emerging opportunities, and promising
  domains on the Apple platform. Recommends fields to explore.
  Apple-ecosystem-specific: considers iOS, iPadOS, watchOS, visionOS,
  macOS capabilities, App Store dynamics, and Apple framework opportunities.
  NOT for: Android/cross-platform, competitor deep-dives, revenue analysis,
  or technical architecture.
version: 0.1.0
argument-hint: "[category-keyword] [region]  — omit keyword for discovery mode"
disable-model-invocation: true
metadata:
  domain: apple-app
---

# apple-app-market-scan

Scan the Apple app landscape. Two modes depending on whether a keyword is provided.

This skill executes. It does not judge.
- Focused mode produces facts only. No ranking, no recommendations.
- Discovery mode recommends categories grounded in gathered data — never in general knowledge.

## Apple platform context (applies to both modes)

When scanning, always consider the Apple-specific landscape:

- **Platforms**: iOS, iPadOS, watchOS, visionOS, macOS. Note which platforms each app targets.
- **Apple frameworks as opportunity signals**: HealthKit, ARKit/RealityKit, CoreML, CarPlay, WidgetKit, ActivityKit (Live Activities), App Intents (Shortcuts/Siri), Apple Intelligence APIs. Frameworks with low adoption among existing apps = potential differentiation.
- **App Store dynamics**: subscription model prevalence, Apple's 30%/15% commission tiers, App Store review guidelines as constraints, App Store feature/editorial potential.
- **Platform moments**: new OS features announced at recent WWDC (visionOS apps, Apple Intelligence integrations) = windows of opportunity where App Store editorial favors early adopters.

## Routing

Decide mode from arguments:
1. If the user provided a category keyword → **Mode A (focused scan)**.
2. If no keyword was provided → **Mode B (discovery scan)**.

---

## Mode A — Focused scan (keyword provided)

**Arguments**: `$0` = category keyword(s), `$1` = region (optional, default: US).

### Steps

1. Ensure `.research/apple-app/` exists in the current project root. Create it if missing.
2. Search these sources, in order:
   - App Store top charts and search results for the category (via web search).
   - Product Hunt launches in the category over the last 6 months.
   - General web: `"{keyword}" Apple app trends 2026`.
3. For each app found, record:
   - Name, developer, App Store rating, review count (approximate is fine).
   - One-line description **verbatim from the store listing** — do not paraphrase.
   - Pricing model (free / freemium / paid / subscription).
   - Platforms supported (iPhone / iPad / Watch / Vision Pro / Mac).
   - Apple frameworks used (if identifiable from the listing, screenshots, or reviews).
   - Last update date (if available).
4. Write the report to `.research/apple-app/market-scan-{keyword}-{YYYY-MM-DD}.md`.

### Report structure

```markdown
# Market scan: {keyword}
Date: {YYYY-MM-DD}
Region: {region}
Sources searched: {list with URLs}

## Apps catalogued
| Name | Developer | Rating | Reviews | Description | Pricing | Platforms | Frameworks | Last update |
|------|-----------|--------|---------|-------------|---------|-----------|------------|-------------|
...

## Patterns observed
- Factual observations only. Examples:
  - "No top-20 app offers Apple Watch companion."
  - "All top apps use subscription model."
  - "No app leverages HealthKit for {X}."

## Platform coverage gaps
- Which Apple platforms are underserved in this category (iPhone only? No iPad version? No Vision Pro?)

## Sources
- URL for every claim above.
```

### Constraints (focused mode)

- Do NOT rank, recommend, or express preference.
- Do NOT speculate on market opportunity.
- Do NOT suggest features or app ideas.
- If data is unavailable, say so. Do not infer.
- Stop at the report. No follow-up questions.

---

## Mode B — Discovery scan (no keyword)

**Arguments**: none (optionally `$0` = region, default: US).

### Steps

1. Ensure `.research/apple-app/` exists in the current project root. Create it if missing.
2. Search broadly:
   - App Store category-level trends — which categories are growing, which are saturated.
   - Recent WWDC announcements and new Apple framework capabilities → categories where new APIs create opportunity.
   - Product Hunt trending app categories (last 3 months).
   - "Apple app market gaps 2026", "underserved App Store categories", "App Store indie developer opportunities".
   - Apple Design Award winners (recent years) — patterns in what Apple promotes.
3. For each candidate category, assess these dimensions:
   - **Category saturation**: high / medium / low (based on number of established players and top-chart stability).
   - **Platform opportunity**: categories where watchOS/visionOS/iPad-specific apps are sparse.
   - **Framework opportunity**: new or underutilized Apple frameworks (e.g., Apple Intelligence APIs launched but few apps use them).
   - **Indie viability**: categories where solo developers or small teams can compete.
   - **Monetization clarity**: categories where users are accustomed to paying.
4. Write the report to `.research/apple-app/market-discovery-{YYYY-MM-DD}.md`.

### Report structure

```markdown
# Market discovery scan
Date: {YYYY-MM-DD}
Region: {region}
Sources searched: {list with URLs}

## Promising domains
| Category | Saturation | Platform opportunity | Framework opportunity | Indie viability | Monetization | Rationale |
|----------|-----------|----------------------|----------------------|-----------------|--------------|-----------|
...

## Top recommendations
Pick 3–5 categories from the table above. For each:
- **Category name**
- **Why now**: specific evidence from the search (cite URLs).
- **Apple-specific angle**: which platform gap or framework opportunity makes this Apple-native.

## Sources
- URL for every claim.

## Next step
To deep-dive into a specific category, run `/apple-app-market-scan {category}`.
```

### Constraints (discovery mode)

- Recommendations must be grounded in data found, not general knowledge.
- Each recommendation must cite specific evidence (e.g., "No top-20 app in {category} supports visionOS despite Apple pushing spatial computing").
- Do NOT suggest specific app ideas — suggest **domains/categories** to explore.
- Do NOT estimate revenue or market size — stay at category-level opportunity.
- After the report, suggest the focused scan as the next step.
