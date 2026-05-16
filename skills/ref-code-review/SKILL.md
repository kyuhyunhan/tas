---
name: ref-code-review
description: Code review checklist and feedback conventions — feedback prefixes ([MUST]/[SHOULD]/[NIT]/[Q]/[PRAISE]), review checklist by area, anti-patterns, response-time guidance. Invoke when reviewing a PR or diff. Do NOT invoke for code authoring or static analysis tasks.
version: 1.0.0
---

# Code Review

Review *the code*, not the author. Feedback is a gift.

## Purpose

1. **Quality assurance** — catch bugs and defects early.
2. **Knowledge sharing** — raise the team's understanding of the codebase.
3. **Consistency** — uphold coding standards.
4. **Growth** — mutual feedback raises everyone's skill.

## Feedback prefixes

| Prefix | Meaning | Required to address? |
|--------|---------|----------------------|
| `[MUST]` | Must be fixed before merge | Yes |
| `[SHOULD]` | Strongly recommended | Optional |
| `[NIT]` | Minor / stylistic | Optional |
| `[Q]` | Question / clarify intent | Optional |
| `[PRAISE]` | Acknowledge good work | — |

## Examples

```markdown
[MUST] Force-unwrap will crash on nil. Use `guard let` and surface a typed error.

Suggested:
guard let value = optional else { return .failure(.invalidData) }

[SHOULD] This function exceeds 40 lines. Splitting `validateInput` and `processData`
will make each unit testable in isolation.

[NIT] `temp` reads as a placeholder. `intermediateResult` conveys intent.

[Q] What's the basis for the 5-second timeout? Is it derived from p95 latency,
or a guess?

[PRAISE] The error-mapping layer here is clean — easy to extend.
```

## Checklist by area

### Functionality

- [ ] Does it implement the requirement correctly?
- [ ] Are happy path AND error paths handled?
- [ ] Are edge cases considered (empty input, boundary values, concurrent access)?

### Code quality

- [ ] Single responsibility per function/class?
- [ ] Names communicate intent?
- [ ] No copy-pasted duplication?
- [ ] No magic numbers / unexplained string constants?

### Architecture

- [ ] Layer dependency rules respected?
- [ ] Abstractions sit at the right boundary (protocol / interface where DI is needed)?
- [ ] No leaking of lower-layer types into upper layers?

### Error handling

- [ ] Every fallible path produces an actionable error?
- [ ] Error messages are user-readable where users see them; developer-readable where they don't?

### Security

- [ ] Sensitive data not logged?
- [ ] Input validated at the boundary?
- [ ] Secrets not committed or hard-coded?

### Tests

- [ ] New behavior covered by new tests?
- [ ] Existing tests still pass?
- [ ] Test names describe what is being verified, not how?

### Performance

- [ ] No accidental O(n²) where O(n) suffices?
- [ ] No retained references that prevent deallocation?
- [ ] Unnecessary work avoided in hot paths?

## Anti-patterns in feedback (don't)

```markdown
"Why did you do it this way?"        // vague + accusatory
"This is wrong."                      // no alternative offered
"I would have done it differently."   // personal preference imposed
```

Replace with:
- A specific concern (what could go wrong)
- A concrete suggestion (or a question, if you're not sure yourself)

## Review culture

1. Review the code, not the person.
2. Questions are not criticism.
3. Feedback is a gift — give it generously, receive it openly.
4. Pursue improvement, not perfection.

## Response-time guidance

| PR size | Expected first response |
|---------|--------------------------|
| Small (< 100 lines) | within 4 hours |
| Medium (100–300 lines) | within 1 day |
| Large (300–500 lines) | within 2 days |
| X-Large (500+ lines) | request a split |

## Output

When this skill produces a review report, group findings by prefix (`MUST` → `SHOULD` → `NIT` → `Q` → `PRAISE`), each with file:line references.
