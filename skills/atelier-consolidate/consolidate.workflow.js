export const meta = {
  name: 'atelier-consolidate',
  description: 'Promote eligible candidates, dream principles via an adversarial proposer/critic loop, then reindex and verify — making the atelier vault fully consistent and queryable, autonomously.',
  phases: [
    { title: 'Survey',  detail: 'read candidates + existing principles' },
    { title: 'Promote', detail: 'critic-gated candidate acceptance' },
    { title: 'Dream',   detail: 'proposer/critic loop → principles' },
    { title: 'Project', detail: 'reindex --full + doctor verify' },
  ],
}

// ── Acceptance criteria the critic enforces (this is the gate that replaces the
//    human). Transparent + editable. Promotions and principles only land when the
//    critic confirms every MUST item; otherwise they are revised or dropped. ──
const PROMOTION_RUBRIC = `A candidate may be ACCEPTED only if ALL hold:
- has a real, specific "why" (not a restated observation);
- is actionable / generalizable (a future session could apply it);
- is NOT pure session status, trivia, or a duplicate of an existing note;
- the assigned target_topic is a genuine retrieval facet (kebab-case, reusable).
Reject (leave as candidate) anything failing any item; give a one-line reason.`

const PRINCIPLE_RUBRIC = `A principle DRAFT may be APPROVED only if ALL hold:
- it generalizes to a clear "when X, do Y" rule (not a project fact);
- it is backed by evidence spanning >= 3 DISTINCT projects;
- it is NOVEL vs the existing always-inject principles (no restatement);
- every source_slug resolves (exists in notes/); drop slugs that don't;
- title is short + imperative; why is one sentence naming what it prevents.
Reject with concrete feedback so the proposer can revise; drop after 3 rounds.`

const SURVEY_SCHEMA = {
  type: 'object', required: ['candidates', 'existing_principles', 'accepted_since_last_dream', 'drift_ok'],
  properties: {
    candidates: { type: 'array', items: { type: 'object', required: ['slug', 'eligible'],
      properties: { slug: { type: 'string' }, eligible: { type: 'boolean' },
        summary: { type: 'string' } } } },
    existing_principles: { type: 'array', items: { type: 'string' } },
    accepted_since_last_dream: { type: 'integer' },  // from atelier_dream_status
    drift_ok: { type: 'boolean' },                   // from atelier_doctor D2
  },
}
const PROMO_SCHEMA = {
  type: 'object', required: ['accepted'],
  properties: { accepted: { type: 'array', items: { type: 'object',
    required: ['slug', 'target_topic'],
    properties: { slug: { type: 'string' }, target_topic: { type: 'string' },
      reason: { type: 'string' } } } },
    rejected: { type: 'array', items: { type: 'object',
      properties: { slug: { type: 'string' }, reason: { type: 'string' } } } } },
}
const DRAFTS_SCHEMA = {
  type: 'object', required: ['drafts'],
  properties: { drafts: { type: 'array', items: { type: 'object',
    required: ['title', 'rule', 'why', 'source_slugs'],
    properties: { title: { type: 'string' }, rule: { type: 'string' },
      why: { type: 'string' }, source_slugs: { type: 'array', items: { type: 'string' } },
      projects: { type: 'array', items: { type: 'string' } } } } } },
}
const VERDICTS_SCHEMA = {
  type: 'object', required: ['verdicts'],
  properties: { verdicts: { type: 'array', items: { type: 'object',
    required: ['title', 'approved'],
    properties: { title: { type: 'string' }, approved: { type: 'boolean' },
      feedback: { type: 'string' } } } } },
}
const PROJECT_SCHEMA = {
  type: 'object', required: ['drift_ok'],
  properties: { drift_ok: { type: 'boolean' }, doctor: { type: 'string' },
    counts: { type: 'string' } },
}

const MCP = `Use ToolSearch (query "select:<tool>") to load each atelier MCP tool before calling it.`

// ── Phase 1: Survey ─────────────────────────────────────────────────────────
phase('Survey')
const survey = await agent(
  `${MCP} Call atelier_learning_review_pending (all), atelier_principle_list,
   atelier_dream_status, and atelier_doctor. Return every candidate with eligible=true
   when its self-check shows must_pass AND forbidden_clear, plus a one-line summary; the
   titles of existing principles; accepted_since_last_dream (from dream_status); and
   drift_ok=true iff doctor D2 (fs-drift) is OK.`,
  { label: 'survey', phase: 'Survey', schema: SURVEY_SCHEMA })

const eligible = (survey?.candidates || []).filter(c => c.eligible)
log(`survey: ${eligible.length} eligible candidate(s), ${(survey?.existing_principles||[]).length} principles, ${survey?.accepted_since_last_dream ?? '?'} since last dream, drift_ok=${survey?.drift_ok}`)

// Early-exit guard (cost): if there is nothing to promote AND nothing new since the
// last dream AND the projection is already clean, skip the expensive fan-out entirely.
if (!eligible.length && (survey?.accepted_since_last_dream || 0) === 0 && survey?.drift_ok === true) {
  log('nothing to promote, nothing new to dream, projection clean — exiting early')
  return { promoted: [], approved_principles: [], critic_rounds: 0, drift_ok: true,
    counts: 'unchanged (early-exit)' }
}

// ── Phase 2: Promote (propose topics → critic gate → apply) ─────────────────
phase('Promote')
let promoted = []
if (eligible.length) {
  const proposal = await agent(
    `${MCP} For each candidate slug below, read it (atelier_learning_search or the file)
     and assign a target_topic (kebab-case retrieval facet) + 1-line rationale.
     Candidates: ${JSON.stringify(eligible.map(c => c.slug))}`,
    { label: 'promote:propose', phase: 'Promote', schema: PROMO_SCHEMA })

  const gated = await agent(
    `You are an adversarial critic. Apply this rubric strictly:\n${PROMOTION_RUBRIC}\n
     Proposed acceptances: ${JSON.stringify(proposal?.accepted || [])}.
     Return only the ones that PASS in "accepted" (keep slug+target_topic), the rest in "rejected".`,
    { label: 'promote:critic', phase: 'Promote', schema: PROMO_SCHEMA })

  for (const item of (gated?.accepted || [])) {
    const r = await agent(
      `${MCP} Call atelier_learning_accept with candidate_slug="${item.slug}",
       target_topic="${item.target_topic}", target_project="atelier". Return the result path.`,
      { label: `accept:${item.slug}`, phase: 'Promote' })
    if (r) promoted.push(item.slug)
  }
  log(`promoted ${promoted.length}/${eligible.length} candidate(s)`)
}

// ── Phase 3: Dream (proposer ↔ critic ping-pong, loop until AC met) ──────────
phase('Dream')
let approvedPrinciples = []
let round = 0
let plan = null
const shouldDream = promoted.length > 0 || (survey?.accepted_since_last_dream || 0) > 0
if (!shouldDream) {
  log('nothing new since last dream — skipping Dream phase')
} else {
plan = await agent(
  `${MCP} Call atelier_dream_plan. Return a compact list of the COHERENT clusters only
   (drop noisy single-stem or project-specific ones): each with cluster_key, shared_terms,
   projects, and the member slugs from synthesize_call.args.source_slugs.`,
  { label: 'dream:plan', phase: 'Dream' })

let drafts = (await agent(
  `${MCP} You are the principle PROPOSER. From these clusters, draft cross-project principles.
   Rubric you must aim to satisfy:\n${PRINCIPLE_RUBRIC}\n
   Existing principles to NOT duplicate: ${JSON.stringify(survey?.existing_principles || [])}.
   Clusters: ${plan}\n Use only source_slugs that appear in the clusters.`,
  { label: 'dream:draft', phase: 'Dream', schema: DRAFTS_SCHEMA }))?.drafts || []

while (drafts.length && round < 3) {
  round++
  const review = await agent(
    `You are an adversarial CRITIC. Apply this rubric strictly:\n${PRINCIPLE_RUBRIC}\n
     Drafts: ${JSON.stringify(drafts)}. Return a verdict per draft (match by title).`,
    { label: `dream:critic:r${round}`, phase: 'Dream', schema: VERDICTS_SCHEMA })

  const verdicts = review?.verdicts || []
  const passing = drafts.filter(d => verdicts.find(v => v.title === d.title && v.approved))
  approvedPrinciples.push(...passing)

  const failing = verdicts.filter(v => !v.approved)
  if (!failing.length) break
  // Revise the rejected drafts with the critic's feedback, then re-review.
  drafts = (await agent(
    `${MCP} You are the PROPOSER. Revise ONLY these rejected drafts using the critic feedback;
     verify each source_slug exists. Drop any that cannot meet the rubric.\n${PRINCIPLE_RUBRIC}\n
     Rejected: ${JSON.stringify(failing)}\n Prior drafts: ${JSON.stringify(drafts)}`,
    { label: `dream:revise:r${round}`, phase: 'Dream', schema: DRAFTS_SCHEMA }))?.drafts || []
}

// Apply: synthesize (proposed) then approve, sequentially (curator lock).
for (const p of approvedPrinciples) {
  await agent(
    `${MCP} Call atelier_principle_synthesize with title=${JSON.stringify(p.title)},
     rule=${JSON.stringify(p.rule)}, why=${JSON.stringify(p.why)},
     source_slugs=${JSON.stringify(p.source_slugs)}, coverage="cross-project",
     priority="on-relevant-prompt". Then call atelier_principle_approve with the returned slug.
     If synthesize errors on an unresolved source slug, drop that slug and retry once.`,
    { label: `principle:${p.title.slice(0, 32)}`, phase: 'Dream' })
}
log(`approved ${approvedPrinciples.length} principle(s) after ${round} critic round(s)`)

// Advance the dream cadence only if we actually ran a dream.
if (plan) await agent(`${MCP} Call atelier_dream_complete.`, { label: 'dream:complete', phase: 'Dream' })
}  // end if (shouldDream)

// ── Phase 4: Project (reindex + verify) — only if something changed or drifted ─
phase('Project')
const changed = promoted.length > 0 || approvedPrinciples.length > 0
let proj = { drift_ok: survey?.drift_ok ?? null, counts: 'unchanged (no reindex needed)' }
if (changed || survey?.drift_ok === false) {
  proj = await agent(
    `${MCP} Call atelier_reindex with full=true, then atelier_doctor. Set drift_ok=true only if
     D2 (fs-drift) is OK. Return doctor summary + the learning_* page-type counts.`,
    { label: 'project', phase: 'Project', schema: PROJECT_SCHEMA })
} else {
  log('no changes and projection already clean — skipping reindex')
}

return {
  promoted, approved_principles: approvedPrinciples.map(p => p.title),
  critic_rounds: round, drift_ok: proj?.drift_ok ?? null, counts: proj?.counts ?? null,
}
