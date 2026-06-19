export const meta = {
  name: 'atelier-consolidate',
  description: 'Tier-transition consolidation on the v7 atomic graph: promote claims query→proactive (acceptance-gated), dream-distill proactive→always (capped T0) and synthesize new cross-claim generalizations via an adversarial proposer/critic loop, then reindex and verify — all on Claim fields, no directory moves.',
  phases: [
    { title: 'Survey',  detail: 'read promote-eligible claims + dream plan + drift' },
    { title: 'Promote', detail: 'critic-gated query→proactive (promote_apply)' },
    { title: 'Dream',   detail: 'proposer/critic loop → synthesize + distill' },
    { title: 'Project', detail: 'reindex --full + doctor verify' },
  ],
}

// ── Acceptance criteria the critic enforces (the gate that replaces the human).
//    Transparent + editable. Transitions land only when the critic confirms every
//    MUST item; otherwise they are revised or dropped. RFC 0005 §7.1: everything
//    here is a FIELD transition on a Claim node, never a directory move. ──
const PROMOTION_RUBRIC = `A claim may be PROMOTED (surfacing: query → proactive) only if ALL hold:
- it is a real, reusable assertion (not session status, trivia, or a duplicate);
- it generalizes beyond its single source (a future turn could act on it);
- its acceptance state is genuinely passed (ac_status: passed) — the engine's
  promote_propose already pre-filters to query+passed; you are the curator that
  decides which of those earn per-turn proactive PUSH;
- elevating it to proactive (it will surface unprompted in-context) is warranted,
  not noise.
Reject (leave at query) anything failing any item; give a one-line reason.`

const SYNTHESIS_RUBRIC = `A synthesized claim DRAFT may be KEPT only if ALL hold:
- it is a genuine cross-claim generalization (a "when X, Y" pattern), NOT a
  restatement of one member claim;
- it is NOVEL vs the existing surfacing:always claims (no duplication);
- every source_claim_id resolves (appears in the cluster it generalizes);
- the relation to its sources is sound (rel: refines = it abstracts them;
  rel: supports = it is corroborated by them);
- it is worth the capped T0 (always) budget.
Reject with concrete feedback so the proposer can revise; drop after 3 rounds.`

const SURVEY_SCHEMA = {
  type: 'object', required: ['proposal_path', 'eligible', 'clusters', 'drift_ok'],
  properties: {
    proposal_path: { type: ['string', 'null'] },   // from atelier_promote_propose
    eligible: { type: 'array', items: { type: 'object', required: ['entry_id'],
      properties: { entry_id: { type: 'string' }, statement: { type: 'string' },
        domain: { type: 'string' }, project: { type: 'string' } } } },
    clusters: { type: 'array', items: { type: 'object',
      properties: { cluster_key: { type: 'string' },
        source_claim_ids: { type: 'array', items: { type: 'string' } },
        shared_terms: { type: 'array', items: { type: 'string' } },
        members: { type: 'array' } } } },
    drift_ok: { type: 'boolean' },                  // from atelier_doctor
  },
}
const PROMO_SCHEMA = {
  type: 'object', required: ['promote'],
  properties: { promote: { type: 'array', items: { type: 'object',
    required: ['entry_id'],
    properties: { entry_id: { type: 'string' }, reason: { type: 'string' } } } },
    rejected: { type: 'array', items: { type: 'object',
      properties: { entry_id: { type: 'string' }, reason: { type: 'string' } } } } },
}
const APPLY_SCHEMA = {
  type: 'object', required: ['promoted'],
  properties: { promoted: { type: 'array', items: { type: 'string' } },
    skipped: { type: 'array' } },
}
const DRAFTS_SCHEMA = {
  type: 'object', required: ['drafts'],
  properties: { drafts: { type: 'array', items: { type: 'object',
    required: ['statement', 'why', 'source_claim_ids'],
    properties: { statement: { type: 'string' }, why: { type: 'string' },
      rel: { type: 'string' },                       // refines | supports
      cluster_key: { type: 'string' },
      source_claim_ids: { type: 'array', items: { type: 'string' } } } } } },
}
const VERDICTS_SCHEMA = {
  type: 'object', required: ['verdicts'],
  properties: { verdicts: { type: 'array', items: { type: 'object',
    required: ['statement', 'approved'],
    properties: { statement: { type: 'string' }, approved: { type: 'boolean' },
      feedback: { type: 'string' } } } } },
}
const DISTILL_SCHEMA = {
  type: 'object', required: ['distill_ids'],
  properties: { distill_ids: { type: 'array', items: { type: 'string' } } },
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
  `${MCP} Build the consolidation picture on the v7 atomic graph:
   1. Call atelier_promote_propose. It writes a proposal file listing every claim
      eligible for query→proactive promotion (surfacing:query AND ac_status:passed,
      the acceptance gate) and returns {path, candidates}. Return its path as
      proposal_path (null if candidates==0), and parse the proposal into "eligible"
      rows (each {entry_id, statement, domain, project}).
   2. Call atelier_dream_plan. Return its clusters of proactive claims as "clusters"
      (each {cluster_key, source_claim_ids = synthesize_call.args.source_claim_ids,
      shared_terms, members}); drop noisy single-stem clusters.
   3. Call atelier_doctor; set drift_ok=true iff it reports v7-green (no fs-drift).`,
  { label: 'survey', phase: 'Survey', schema: SURVEY_SCHEMA })

const eligible = survey?.eligible || []
const clusters = survey?.clusters || []
log(`survey: ${eligible.length} promote-eligible claim(s), ${clusters.length} dream cluster(s), drift_ok=${survey?.drift_ok}`)

// Early-exit guard (cost): nothing to promote, no clusters to dream, projection clean.
if (!eligible.length && !clusters.length && survey?.drift_ok === true) {
  log('nothing to promote, no clusters to dream, projection clean — exiting early')
  return { promoted: [], synthesized: [], distilled: [], critic_rounds: 0,
    drift_ok: true, counts: 'unchanged (early-exit)' }
}

// ── Phase 2: Promote (query→proactive, acceptance-gated) ────────────────────
phase('Promote')
let promoted = []
if (eligible.length && survey?.proposal_path) {
  const proposal = await agent(
    `${MCP} Decide which acceptance-gated claims earn the proactive tier. For each
     eligible claim below, read its statement (it is in the row; atelier_recall if
     you need context) and return it under "promote" (with a 1-line reason) or
     "rejected". Eligible: ${JSON.stringify(eligible)}`,
    { label: 'promote:propose', phase: 'Promote', schema: PROMO_SCHEMA })

  const gated = await agent(
    `You are an adversarial critic. Apply this rubric strictly:\n${PROMOTION_RUBRIC}\n
     Proposed promotions: ${JSON.stringify(proposal?.promote || [])}.
     Return only the ones that PASS in "promote" (keep entry_id), the rest in "rejected".`,
    { label: 'promote:critic', phase: 'Promote', schema: PROMO_SCHEMA })

  const toPromote = new Set((gated?.promote || []).map(p => p.entry_id))
  if (toPromote.size) {
    // Edit the proposal file in place: flip `promote: false` → true for the chosen
    // entry_ids, then apply. promote_apply re-checks the acceptance gate (defence
    // in depth) and performs the query→proactive field transition on each claim.
    const applied = await agent(
      `${MCP} Edit the promotion proposal at "${survey.proposal_path}": for each
       block whose entry_id is in ${JSON.stringify([...toPromote])}, change its
       "promote: false" line to "promote: true" (leave all others false). Then call
       atelier_promote_apply with proposal="${survey.proposal_path}". Return the
       engine's "promoted" entry_id list and any "skipped".`,
      { label: 'promote:apply', phase: 'Promote', schema: APPLY_SCHEMA })
    promoted = applied?.promoted || []
  }
  log(`promoted ${promoted.length}/${eligible.length} claim(s) query→proactive`)
}

// ── Phase 3: Dream (synthesize new always-claims + distill proactive→always) ─
phase('Dream')
let synthesized = []
let distilled = []
let round = 0
if (!clusters.length) {
  log('no clusters — skipping Dream phase')
} else {
  // Proposer: draft cross-claim generalizations from the clusters.
  let drafts = (await agent(
    `${MCP} You are the synthesis PROPOSER. From these clusters of proactive claims,
     draft cross-claim generalizations. Aim to satisfy:\n${SYNTHESIS_RUBRIC}\n
     For each draft give statement, why, rel (refines|supports), cluster_key, and
     source_claim_ids drawn ONLY from that cluster's members.
     Existing surfacing:always claims to NOT duplicate: (check via atelier_recall
     tier-always before drafting).\n Clusters: ${JSON.stringify(clusters)}`,
    { label: 'dream:draft', phase: 'Dream', schema: DRAFTS_SCHEMA }))?.drafts || []

  let kept = []
  while (drafts.length && round < 3) {
    round++
    const review = await agent(
      `You are an adversarial CRITIC. Apply this rubric strictly:\n${SYNTHESIS_RUBRIC}\n
       Drafts: ${JSON.stringify(drafts)}. Return a verdict per draft (match by statement).`,
      { label: `dream:critic:r${round}`, phase: 'Dream', schema: VERDICTS_SCHEMA })

    const verdicts = review?.verdicts || []
    kept.push(...drafts.filter(d => verdicts.find(v => v.statement === d.statement && v.approved)))

    const failing = verdicts.filter(v => !v.approved)
    if (!failing.length) break
    drafts = (await agent(
      `${MCP} You are the PROPOSER. Revise ONLY these rejected drafts using the critic
       feedback; verify each source_claim_id appears in its cluster. Drop any that
       cannot meet the rubric.\n${SYNTHESIS_RUBRIC}\n
       Rejected: ${JSON.stringify(failing)}\n Prior drafts: ${JSON.stringify(drafts)}`,
      { label: `dream:revise:r${round}`, phase: 'Dream', schema: DRAFTS_SCHEMA }))?.drafts || []
  }

  // Apply ② — synthesize each kept draft (engine mints a new surfacing:always claim,
  // generated_by:dream, linked refines/supports to its sources). Idempotent: an
  // already-covered cluster is skipped by the engine.
  for (const d of kept) {
    const r = await agent(
      `${MCP} Call atelier_dream_synthesize with
       source_claim_ids=${JSON.stringify(d.source_claim_ids)},
       statement=${JSON.stringify(d.statement)}, why=${JSON.stringify(d.why)},
       rel=${JSON.stringify(d.rel || 'refines')},
       cluster_key=${JSON.stringify(d.cluster_key || '')}.
       Return {entry_id, skipped}.`,
      { label: `synthesize:${(d.statement || '').slice(0, 32)}`, phase: 'Dream' })
    if (r && r.skipped !== true) synthesized.push(d.statement)
  }
  log(`synthesized ${synthesized.length} new always-claim(s) after ${round} critic round(s)`)

  // Apply ① — distill: elevate the strongest PROACTIVE claims into the capped T0
  // (always) budget. The proposer nominates; the critic-vetted promotions this run
  // plus existing proactive claims are the candidate pool. distill is a field
  // transition (proactive→always) and only fires on claims currently at proactive.
  const distillPlan = await agent(
    `${MCP} You are the T0 curator. The `always` budget is small and hard-capped
     (recall keeps only the most relevant). From the proactive claims in these
     clusters ${JSON.stringify(clusters.map(c => c.source_claim_ids).flat())},
     nominate ONLY the few highest-value, broadly-applicable ones to distill into
     the always budget (return their entry_ids in distill_ids; empty is fine).`,
    { label: 'dream:distill:plan', phase: 'Dream', schema: DISTILL_SCHEMA })

  const distillIds = distillPlan?.distill_ids || []
  if (distillIds.length) {
    const dr = await agent(
      `${MCP} Call atelier_dream_distill with claim_ids=${JSON.stringify(distillIds)}.
       It elevates only claims currently at proactive (skips others). Return its
       "elevated" list as distill_ids.`,
      { label: 'dream:distill:apply', phase: 'Dream', schema: DISTILL_SCHEMA })
    distilled = dr?.distill_ids || []
  }
  log(`distilled ${distilled.length} claim(s) proactive→always (capped T0)`)

  // Advance the dream cadence only after a clean pass.
  await agent(`${MCP} Call atelier_dream_complete.`, { label: 'dream:complete', phase: 'Dream' })
}

// ── Phase 4: Project (reindex + verify) — only if something changed or drifted ─
phase('Project')
const changed = promoted.length > 0 || synthesized.length > 0 || distilled.length > 0
let proj = { drift_ok: survey?.drift_ok ?? null, counts: 'unchanged (no reindex needed)' }
if (changed || survey?.drift_ok === false) {
  proj = await agent(
    `${MCP} Call atelier_reindex with full=true, then atelier_doctor. Set drift_ok=true
     only if doctor reports v7-green (no fs-drift). Return doctor summary + the
     surfacing-tier claim counts (query/proactive/always).`,
    { label: 'project', phase: 'Project', schema: PROJECT_SCHEMA })
} else {
  log('no changes and projection already clean — skipping reindex')
}

return {
  promoted, synthesized, distilled, critic_rounds: round,
  drift_ok: proj?.drift_ok ?? null, counts: proj?.counts ?? null,
}
