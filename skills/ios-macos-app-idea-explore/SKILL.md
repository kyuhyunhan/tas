---
name: ios-macos-app-idea-explore
description: >
  Ideation-phase skill for crystallizing Apple app concepts.
  Strongly coupled with ios-macos-app-market-research: uses market research
  artifacts as primary grounding for Socratic exploration.
  Iteratively refines an idea through forcing questions, assumption
  surfacing, and convergence tracking until the concept is crystallized.
  Apple-ecosystem-aware: considers App Store guidelines, platform
  capabilities (iOS/iPadOS/watchOS/visionOS/macOS), Apple frameworks,
  and platform-specific constraints throughout.
  Pipeline: market-scan → idea-explore → /plan → (future: design,
  engineering, decision-making skills).
  NOT for: market research (use ios-macos-app-market-research), technical
  architecture, UI design, or implementation planning.
version: 0.1.0
argument-hint: "[rough idea in quotes]"
disable-model-invocation: true
metadata:
  domain: ios-macos-app
  pipeline-position: ideation
  upstream: ios-macos-app-market-research
  downstream: /plan
---

# ios-macos-app-idea-explore

Crystallize a rough Apple app idea through iterative Socratic exploration.

This skill asks. It does not propose. Your judgment stays with you.
- Do not propose features, solutions, or technical approaches.
- Do not evaluate the idea as good or bad.
- Output is a structured exploration document, not a recommendation.

## Pipeline position

`ios-macos-app-market-research` (discovery/focused) → **`ios-macos-app-idea-explore`** → `/plan` → (future: design, engineering, decision skills).

This skill expects market research artifacts from `ios-macos-app-market-research` as its grounding. Without them, it operates in a degraded mode with explicit warnings.

## Implementation approach

Prompt-only. No code, no state files, no metrics.
- Conversation history IS the runtime state.
- The exploration document IS the persistent state.
- Progress is model judgment expressed as structured observation, not a computed score.
- Phase transitions are STOP gates: stop, wait for user response, then proceed.

## Convergence loop

```
Phase 0 (first iteration only): artifact discovery
        │
        ▼
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
| Alternative awareness | Competitive landscape understanding | New alternatives or sharper differentiation | "I don't know what else exists" despite market data being available |
| Kill condition clarity | Biggest-risk identification | Specific and testable | Vague ("it might not work") |
| Apple platform fit | Why this must be a native Apple app | Platform choice tied to Apple capabilities | "iPhone I guess" or no answer to "why not web?" |

---

## Phase 0 — Artifact discovery (first iteration only)

Glob `.research/ios-macos-app/market-scan-*.md` AND `.research/ios-macos-app/market-discovery-*.md`.

- **If focused market scan found** (strong path): read the most recent of each type. State:
  > "Market research loaded: `{filename}`. {N} apps catalogued in {category}. Platform gaps identified: {list}. This data will ground the exploration."

- **If only discovery report found**: State:
  > "Discovery report loaded: `{filename}`. Promising domains identified: {list}. No focused scan for this specific category — consider running `/ios-macos-app-market-research {keyword}` first for stronger grounding."

- **If nothing found** (degraded path — warn explicitly):
  > "⚠️ No market research found in `.research/ios-macos-app/`. This skill works best with market data from `/ios-macos-app-market-research`. Proceeding without market grounding — all competitive claims will be unvalidated assumptions. Strongly consider running market scan first."

---

## Phase 1 — Socratic interview

Rules:
- Ask questions **ONE AT A TIME**. Wait for the user's response before asking the next.
- After each answer, identify ONE hidden assumption and surface it as the next question.
- After 3 confident answers without pushback, ask: "You've answered confidently. What's the part you're least sure about?" (dialectic guard).
- At least once per iteration, probe Apple platform fit: does this idea genuinely benefit from being native Apple, or would web/cross-platform serve better?

### First iteration — eight forcing question categories

| # | Category | Example |
|---|----------|---------|
| 1 | Problem | "What specific frustration does this address? For whom exactly?" |
| 2 | Current alternatives | "How do people solve this today without your app? What's inadequate?" (If market scan loaded: "The scan shows {App X}, {App Y} in this space. Which comes closest to what you envision, and where does it fall short?") |
| 3 | Hidden capability | "What can this do that you haven't stated yet? What's the 10x version?" |
| 4 | Scope boundary | "What is explicitly NOT part of this? What would you refuse to build?" |
| 5 | Kill condition | "What assumption, if wrong, kills this idea on arrival?" |
| 6 | Measurement | "How would you know this succeeded? One number after 3 months?" |
| 7 | Apple platform fit | "Which Apple platforms does this need? iPhone-only, or Watch/iPad/Vision Pro? Why?" (If market scan shows platform gaps: "The scan shows no competitor targets {platform}. Is that a gap you'd exploit or a signal that platform doesn't fit?") |
| 8 | Apple framework leverage | "Are there Apple-specific capabilities (HealthKit, ARKit, Shortcuts, Live Activities, Apple Intelligence) that make this fundamentally better than a web app?" (If market scan flagged framework opportunities: reference them directly.) |

### Subsequent iterations — targeted refinement

Before asking anything:
1. Re-read the current exploration document and progress ledger.
2. Identify the track(s) with lowest clarity or labeled "stagnant".
3. Prioritize questions that address those tracks' open gaps.

While asking:
- Cross-reference market scan on every iteration. If the user's claim contradicts the scan data, surface that immediately.
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
Market research: {filename or "None"}
Pipeline: ios-macos-app-market-research → **ios-macos-app-idea-explore** → /plan

## Idea in one sentence
{synthesized — refined each iteration}

## Problem statement
{user's words — do not paraphrase}

## Target user
{from interview}

## Apple platform strategy
**Target platforms**: {iOS / iPadOS / watchOS / visionOS / macOS — with rationale per platform}
**Key Apple frameworks**: {HealthKit / ARKit / etc. — only those actually relevant}
**Why native Apple?**: {the specific reason this should be an Apple app, not web/cross-platform}
**App Store considerations**: {pricing model, review guideline risks, editorial opportunity}

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

## Market context
{if report loaded: key facts, platform gaps, framework opportunities, competitive landscape — all from report with source URLs}
{if no report: "No market data. Run /ios-macos-app-market-research before trusting competitive claims."}

## Contradictions noted
{user claims vs. market data, listed factually — do not resolve them}

## Progress ledger
| Track | Status | Delta from last iteration |
|-------|--------|---------------------------|
| Problem clarity | {progressing/stable/stagnant} | {what changed or "no change"} |
| Assumption coverage | {X}/{Y} confirmed | {+N confirmed this round} |
| Scope stability | {stable/shifting} | {what moved} |
| Alternative awareness | {progressing/stable/stagnant} | {what changed} |
| Kill condition clarity | {clear/vague} | {what changed} |
| Apple platform fit | {clear/unclear} | {what changed} |
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
- If the user contradicts market data, note factually. Do not resolve.
- Each iteration overwrites the same file. No versioned copies.
- Maximum 7 iterations hard cap.
- Output = structured exploration document, not a recommendation.
- The `/plan` suggestion at exit is a suggestion, not an automatic action.
