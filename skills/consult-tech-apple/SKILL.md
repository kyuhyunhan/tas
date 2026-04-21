---
name: consult-tech-apple
description: >
  Apple-platform technology lens consultation for a decision point
  raised by a main skill. Applies Apple framework, Human Interface
  Guidelines, and App Store policy knowledge to a packaged decision
  request and returns a fixed-shape tradeoff analysis. Scope:
  iOS (iPhone/iPad) and macOS desktop apps only. Pure function:
  reads the request and referenced main artifact, writes one
  response artifact.
  Use when a main-grade skill is blocked on an Apple-platform
  decision — iOS vs macOS vs both, which Apple frameworks to
  leverage, SwiftUI vs AppKit vs Mac Catalyst, MAS vs direct
  distribution — and the user cannot evaluate the options alone.
  NOT for: watchOS, visionOS, tvOS — out of scope. NOT for:
  general (non-Apple) tech choices (use consult-tech), product
  strategy (use consult-product), UX pattern that is not Apple-
  specific (use consult-ux). NOT for making the decision —
  returns tradeoff structure, never "you should do X".
version: 0.1.0
argument-hint: "[path to .research/consult/request-*.md]"
disable-model-invocation: true
metadata:
  domain: consult
---

# consult-tech-apple

Apply the Apple-platform technology lens to a packaged decision request.

This skill structures tradeoffs. It does not decide.
- Do not answer general tech questions — those are `consult-tech`'s.
- Do not answer watchOS / visionOS / tvOS questions — explicitly out of scope.
- Do not write Swift code, entitlements, or plist snippets.

## Scope

**In scope**:
- Platform mix — iOS only / macOS only / iOS + macOS / the shape of code sharing between them.
- UI framework — SwiftUI / AppKit / UIKit / Mac Catalyst / SwiftUI+AppKit bridges; which fits the proposed app shape.
- Apple framework leverage — HealthKit, App Intents/Shortcuts, WidgetKit, ActivityKit (Live Activities), CoreML, CoreData/SwiftData, CloudKit, PDFKit, Vision, Natural Language, Spotlight, Accessibility API, Keychain, StoreKit, etc.
- Distribution — Mac App Store vs direct distribution (Sparkle-updated DMG, Setapp, Homebrew Cask); iOS only through App Store (+ TestFlight).
- App Store policy risk — review guidelines that commonly block certain designs (subscription phrasing, external payment, background-task misuse).
- Native vs web bridging — when WKWebView is the right call vs a liability; when embedded Electron-style apps fail Apple review.

**Out of scope**:
- watchOS / visionOS / tvOS. Decline these outright in the response; do not speculate.
- Non-Apple cross-platform frameworks evaluated on their own merits → `consult-tech`.
- Product strategy — "should this feature exist at all" → `consult-product`.
- General UX heuristics not Apple-specific → `consult-ux`.
- App Store pricing tier strategy as GTM → `consult-gtm`.

## Input

- Path to request artifact at `.research/consult/request-{topic}-{timestamp}.md`.
- Read the referenced main artifact.

## Process

Identical to the `consult-*` family:

1. Read request + referenced main artifact.
2. Scope-check.
3. Apply Apple-specific frameworks.
4. Structure as tradeoffs.
5. Write response artifact.

## Frameworks applied (Apple-platform lens)

- **Platform capability gate** — list the specific OS-level capabilities a proposed app genuinely needs (Accessibility API, global hotkey, floating overlay, background audio, Live Activities, AppIntents for Siri/Shortcuts). If zero entries, the "must be native" claim is weak and the answer should flag a web/PWA alternative.
- **Framework age and stability** — SwiftUI on macOS reaches production stability at ~macOS 14; earlier SDK targets imply AppKit + bridging. State this explicitly when it affects the option.
- **Code-sharing shape** — SwiftUI-first shared codebase, Mac Catalyst, AppKit+UIKit parallel targets, or platform-specific. Each has distinct effort and parity profile.
- **App Store review surface** — rules that commonly intersect indie apps: 3.1.1 in-app purchase, 4.0 copycat, 5.1.1 data collection, 2.5.1 public API. Flag when the proposed design hits one.
- **Distribution moat** — MAS gives editorial + discovery but takes 15–30% and blocks certain capabilities; direct gives freedom + full revenue but no discovery. Name which trade is operative.
- **HIG alignment** — where the proposed design would feel un-native (platform-specific conventions: title bar buttons on macOS, back swipe on iOS, etc.).

One to three frameworks per response. Name them.

## Artifact

Write to `.research/consult/response-tech-apple-{topic}-{timestamp}.md`.

### Fixed response template

Same 5-section template as the `consult-*` family. Sections: `Decision context` / `Options analyzed` / `Tradeoff structure` / `Reframings` / `Out of my lane`.

## Stop conditions

- Response artifact is written.
- Every option in the request is covered.

## Constraints

- Do NOT cover watchOS, visionOS, or tvOS. Decline in the response.
- Do NOT cover non-Apple cross-platform frameworks on their own merits.
- Do NOT write Swift code, entitlement plist entries, or App Store Connect config.
- Do NOT output prose outside the template.
- Each run overwrites the same-named response.
- Output = fixed-template response artifact only.
