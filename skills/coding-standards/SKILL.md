---
name: coding-standards
description: Language-agnostic coding standards — three principles (Readability First, Consistency, Explicit over Implicit), naming conventions, code structure rules, comment guidance, and forbidden patterns (force-unwrap, magic numbers, god object). Invoke when writing or reviewing code on any project. Do NOT invoke for language-specific patterns — those belong in language-specific skills (e.g., swift-patterns).
version: 1.0.0
---

# Coding Standards

Project-agnostic baseline. Language-specific rules live in their own skills.

## Three principles

### 1. Readability First

- Names communicate intent. A reader should not have to re-derive the *why* from the *what*.
- Functions do one thing.
- Comments explain *why*, not *what* — well-named code already says what.

### 2. Consistency

- Match the surrounding codebase's style.
- Use the project's auto-formatter; do not negotiate with it line by line.
- One pattern per problem class — pick one and stick to it.

### 3. Explicit over Implicit

- Annotate types when inference would force the reader to chase a definition.
- Side effects belong in named functions, not buried inside getters or initializers.
- Defaults that matter (timeouts, retry counts, cache TTLs) live in named constants.

## Naming

| Target | Style | Example |
|--------|-------|---------|
| File / Class / Struct | PascalCase | `TranslationService`, `UserProfile` |
| Function / Variable | camelCase | `fetchUser()`, `targetLanguage` |
| Boolean | `is` / `has` / `can` prefix | `isValid`, `hasPermission`, `canRetry` |
| Protocol / Interface | Noun or adjective | `Translatable`, `Repository` |
| Constant (project-scoped) | Project's idiomatic constant style | language-dependent |

### Good vs. bad

```
Good:
- fetchUserProfile()    // verb + noun
- isValid               // boolean prefix
- maximumRetryCount     // intent-revealing

Bad:
- doIt()                // vague
- flag                  // meaning unclear
- temp, tmp, x, y       // placeholder names that survived into review
```

### Abbreviations

```
Allowed (industry-standard, recognizable): URL, HTTP, API, ID, UUID, JSON, OCR, UI
Avoid (ad-hoc shortenings):                 mgr, btn, lbl, usr, msg
```

## Code structure

### Function rules

- One responsibility per function. If you can describe it as "X *and* Y," split.
- Pure where possible. If a function has side effects, the name should hint at them (`save`, `emit`, `write`).
- Parameters: 5 or fewer. More than that, group into a struct/object.

### Maximum guidelines (soft limits)

| Target | Soft limit | When to split |
|--------|------------|----------------|
| Line | 120 chars | Auto-formatter usually handles this |
| Function | 40 lines | Extract sub-functions |
| File | 400 lines | Split by responsibility |
| Parameters | 5 | Group into a parameter object |

These are guidelines, not laws. A 50-line function that is genuinely cohesive beats five 10-line functions that fragment one logical operation.

## Comment guidance

### When to comment

- The *why* — design decision, non-obvious constraint, workaround for a known issue.
- A non-trivial algorithm whose intent is not obvious from the code.
- External-facing API documentation.
- `TODO` / `FIXME` markers (with an issue link or owner).

### When NOT to comment

- Restating what the next line does.
- Documenting a name that is already self-explanatory.
- Commenting out dead code (delete it; version control remembers).

## Forbidden patterns

### Force-unwrap (or equivalent in your language)

Use early return with a typed error, or nil-coalescing with an explicit default. The narrow exceptions are constant literals provably non-nil and test code where the failure *is* the assertion.

### Magic numbers

```
// Bad
if retryCount > 3 { ... }

// Good
let maxRetryCount = 3
if retryCount > maxRetryCount { ... }
```

### God object

A class that "does everything" is a co-located coupling problem. Split by responsibility:

```
Bad:    class AppManager { login(); translate(); saveSettings() }
Good:   class AuthManager  { login() }
        class TranslationService { translate() }
        class SettingsStorage { saveSettings() }
```

## Authoring checklist

- [ ] Names reveal intent
- [ ] Each function does one thing
- [ ] No force-unwrap (or language equivalent) outside the named exceptions
- [ ] No magic numbers
- [ ] Early return where guards make the happy path clearer
- [ ] Comments explain *why*, never *what*
- [ ] Section markers (`MARK`, `// region`, etc.) where the language idiom uses them
