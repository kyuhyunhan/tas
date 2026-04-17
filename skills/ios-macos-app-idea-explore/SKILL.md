---
name: ios-macos-app-idea-explore
description: >
  Ideation-phase skill for crystallizing iOS or macOS app concepts.
  Iteratively refines an idea through forcing questions, assumption
  surfacing, and convergence tracking until the concept is crystallized.
  Scope strictly: iOS (iPhone/iPad) and macOS desktop apps. Excludes
  watchOS, visionOS, tvOS.
  Pipeline: idea-explore → /plan → (future: design, engineering,
  decision-making skills). Does NOT depend on any other skill — starts
  directly from the user's rough idea.
  NOT for: market research (market-research skill is isolated and separate),
  technical architecture, UI design, or implementation planning.
version: 0.2.0
argument-hint: "[rough idea in quotes]"
disable-model-invocation: true
metadata:
  domain: ios-macos-app
  pipeline-position: ideation
  downstream: /plan
---

# ios-macos-app-idea-explore

Crystallize a rough iOS or macOS app idea through iterative Socratic exploration.

This skill asks. It does not propose. Your judgment stays with you.
- Do not propose features, solutions, or technical approaches.
- Do not evaluate the idea as good or bad.
- Output is a structured exploration document, not a recommendation.

## Scope

**In scope**: iOS (iPhone, iPad) and macOS desktop apps.
**Out of scope**: watchOS, visionOS, tvOS. If the user proposes an idea that centers on an out-of-scope platform, ask them to reframe for iOS/macOS or step outside this skill.

## Pipeline position

**`ios-macos-app-idea-explore`** → `/plan` → (future: design, engineering, decision skills).

This skill starts directly from the user's rough idea. It does not load external market research or other artifacts. Whatever context the user brings in their head is the starting point.

## Implementation approach

Prompt-only. No code, no state files, no metrics.
- Conversation history IS the runtime state.
- The exploration document IS the persistent state.
- Progress is model judgment expressed as structured observation, not a computed score.
- Phase transitions are STOP gates: stop, wait for user response, then proceed.

## Convergence loop

```
Phase 1: Socratic interview ◄───── re-read document,
        │                           focus on tracks with
        ▼                           lowest clarity
Phase 2: crystallize + progress assessment
        │
        ▼
Phase 3: signal + user decides
        │
        └── user continues → Phase 1 (next iteration)
            user stops     → suggest /plan
```

Maximum 7 iterations hard cap.

## Progress ledger

After each iteration, assess each track. Convergence = all 6 tracks stable. Stagnation = any track stuck for 2+ iterations.

| Track | What it measures | Progressing | Stagnant |
|-------|-----------------|-------------|----------|
| Problem clarity | How specific is the problem + who has it | New nuance, narrower framing | Same statement, no refinement |
| Assumption coverage | Confirmed vs. total assumptions | Moving from unconfirmed → confirmed/contradicted | Same assumptions stuck on "unconfirmed" for 2+ rounds |
| Scope stability | Boundary changes | Held or narrowed intentionally | Keeps expanding without resolution |
| Alternative awareness | Competitive landscape understanding | New alternatives or sharper differentiation | "I don't know what else exists" persists |
| Kill condition clarity | Biggest-risk identification | Specific and testable | Vague ("it might not work") |
| iOS/macOS platform fit | Why this must be a native iOS or macOS app | Platform choice tied to specific iOS or macOS capabilities | "iPhone I guess" with no reasoning, or no answer to "why not web, why not macOS too?" |

---

## Phase 1 — Socratic interview

Rules:
- Ask questions **ONE AT A TIME**. Wait for the user's response before asking the next.
- After each answer, identify ONE hidden assumption and surface it as the next question.
- After 3 confident answers without pushback, ask: "You've answered confidently. What's the part you're least sure about?" (dialectic guard).
- At least once per iteration, probe iOS/macOS platform fit: does this idea genuinely benefit from being a native iOS or macOS app, or would a web app or cross-platform solution serve better?

### First iteration — eight forcing question categories

| # | Category | Example |
|---|----------|---------|
| 1 | Problem | "What specific frustration does this address? For whom exactly?" |
| 2 | Current alternatives | "How do people solve this today without your app? What's inadequate? What other apps in this space have you looked at?" |
| 3 | Hidden capability | "What can this do that you haven't stated yet? What's the 10x version?" |
| 4 | Scope boundary | "What is explicitly NOT part of this? What would you refuse to build?" |
| 5 | Kill condition | "What assumption, if wrong, kills this idea on arrival?" |
| 6 | Measurement | "How would you know this succeeded? One number after 3 months?" |
| 7 | iOS/macOS platform fit | "iOS, macOS, or both? Why? And why not web instead?" |
| 8 | Apple framework leverage | "Are there Apple-specific capabilities (HealthKit, Shortcuts via App Intents, Live Activities, Apple Intelligence, Mac Catalyst, SwiftUI, CoreML) that make this fundamentally better than a web app or cross-platform solution?" |

### Subsequent iterations — targeted refinement

Before asking anything:
1. Re-read the current exploration document and progress ledger.
2. Identify the track(s) with lowest clarity or labeled "stagnant".
3. Prioritize questions that address those tracks' open gaps.

While asking:
- If a track is stagnant, try a **lateral question**: reframe from a different angle rather than repeating the same approach.
- Do NOT repeat questions already answered unless the user's responses revealed new territory.
- Fewer questions per iteration as convergence approaches: 8–10 in round 1, potentially 4–5 in later rounds.

### Stop conditions for current iteration

- User says "enough" / expresses impatience → **escape hatch**: ask the 2–3 most critical remaining questions for the weakest tracks, acknowledge "Compressing — focusing on gaps that matter most", then proceed to Phase 2.
- All eight categories covered for this iteration.

---

## Phase 2 — Crystallize + progress assessment

Overwrite (same filename each iteration): `.research/ios-macos-app/idea-exploration-{slug}-{YYYY-MM-DD}.md`.

### Document template

```markdown
# Idea Exploration: {name}
Date: {YYYY-MM-DD}
Iteration: {N}
Pipeline: **ios-macos-app-idea-explore** → /plan

## Idea in one sentence
{synthesized — refined each iteration}

## Problem statement
{user's words — do not paraphrase}

## Target user
{from interview}

## Platform strategy
**Target platforms**: iOS / macOS / both (with rationale for each platform chosen)
**Key Apple frameworks**: {UIKit / SwiftUI / AppKit / HealthKit / App Intents / CoreML / etc. — only those actually relevant}
**Why native (not web)?**: {the specific reason this should be an iOS or macOS app, not a web app or cross-platform solution}
**App Store considerations**: {pricing model, review guideline risks, editorial opportunity, MAS vs. direct distribution for Mac}

## Assumptions surfaced
1. {assumption} — confirmed / unconfirmed / contradicted by research
2. ...
(Assumptions carry across iterations. Status updates as exploration deepens.)

## Scope boundaries
**In**: ...
**Out**: ...
**Deferred to future phases**: {things that belong in design/engineering/decision skills, not ideation}

## Open questions
- {unresolved — should shrink with each iteration}
- {flag questions that require design phase vs. engineering phase to answer}

## Progress ledger
| Track | Status | Delta from last iteration |
|-------|--------|---------------------------|
| Problem clarity | {progressing/stable/stagnant} | {what changed or "no change"} |
| Assumption coverage | {X}/{Y} confirmed | {+N confirmed this round} |
| Scope stability | {stable/shifting} | {what moved} |
| Alternative awareness | {progressing/stable/stagnant} | {what changed} |
| Kill condition clarity | {clear/vague} | {what changed} |
| iOS/macOS platform fit | {clear/unclear} | {what changed} |
```

---

## Phase 3 — Signal + user decides

After the document is written, assess the ledger and present ONE of three signals. STOP after the signal — wait for the user's decision.

### Signal A — Convergence detected
All tracks stable, open questions minimal.
> "Iteration {N} complete. All 6 tracks are stable — the idea appears crystallized.
> - {X}/{Y} assumptions confirmed
> - {W} open questions remaining (down from {prev})
>
> The exploration has converged. When you're ready to design the implementation, consider using `/plan` to create an execution plan based on this document."

### Signal B — Stagnation detected
One or more tracks stuck for 2+ iterations.
> "Iteration {N} complete. Stagnation detected on **{track name}**: {specific observation, e.g., 'Kill condition remains vague — "it might not work" hasn't been refined in 2 rounds.'}
>
> Options:
> 1. Try a different angle on this track
> 2. Accept the gap and note it as an open risk
> 3. Stop here and move to `/plan`"

### Signal C — Progress continuing
Some tracks improved, others remain open.
> "Iteration {N} complete.
> - Progress: {tracks that improved this round}
> - Still open: {tracks that need work}
> - {X}/{Y} assumptions confirmed, {W} open questions
>
> Continue refining?"

### User's decision

- **Continue** → Phase 1 (next iteration mode).
- **Stop** → suggest `/plan`:
  > "When you're ready, use `/plan` to create an execution plan based on this exploration document."

  Do NOT automatically enter plan mode. Only suggest it.

---

## Flow control

- **STOP gates**: After each question in the interview, STOP. Do not ask the next question until the user responds. After crystallization, STOP. Do not proceed to the next iteration without user decision.
- **Mode lock**: Once an iteration starts (Phase 1), complete all three phases (1→2→3) before allowing the user to redirect. A tangential comment does not derail the current phase.
- **Escape hatch**: If the user says "enough" or expresses impatience mid-interview, compress — ask the 2–3 most critical remaining questions for the weakest tracks, acknowledge compression, then proceed to Phase 2.
- **No silent drift**: If the conversation drifts away from the current track, acknowledge and redirect: "That's interesting, but let's resolve {current track} first. We can explore that in the next iteration."
- **Hypothesis cap for stagnation**: If the same track receives 3 consecutive vague answers, don't keep pushing. Note it as stagnant and move on.

## Constraints

- Do NOT propose solutions, features, or technical approaches.
- Do NOT evaluate the idea as good or bad.
- Do NOT skip the signal + user decision. Always let the user decide.
- Each iteration overwrites the same file. No versioned copies.
- Maximum 7 iterations hard cap.
- Output = structured exploration document, not a recommendation.
- The `/plan` suggestion at exit is a suggestion, not an automatic action.
