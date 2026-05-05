---
name: swift-patterns
description: Swift language patterns — async/await, optional handling, error handling, memory management, value vs. reference types, Sendable/Actor. Invoke when writing or reviewing Swift code on any Apple platform. Do NOT invoke for non-Swift code or for Apple framework specifics (HIG, AppKit, SwiftUI navigation, etc.) — those belong elsewhere.
version: 1.0.0
metadata:
  domain: swift
---

# Swift Patterns

Language-level patterns for Swift. Platform-agnostic where possible; Apple-platform additions are clearly scoped.

## Async / Await

### Prefer async/await over completion handlers

```swift
// Good
func fetchUser(id: String) async throws -> User {
    return try await userService.load(id: id)
}

// Avoid
func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void)
```

### Task

```swift
func performWork() {
    Task {
        do {
            let result = try await heavyWork()
            await MainActor.run { update(result) }
        } catch {
            await MainActor.run { showError(error) }
        }
    }
}
```

### MainActor

```swift
@MainActor
final class ViewPresenter {
    func update(_ value: Value) { /* UI update */ }
}

// Or explicit hop
await MainActor.run { self.updateUI() }
```

### Concurrency primitives

```swift
// async let — small, fixed fan-out
async let a = serviceA.load()
async let b = serviceB.load()
let (x, y) = try await (a, b)

// TaskGroup — dynamic fan-out
func process(_ items: [Item]) async throws -> [Result] {
    try await withThrowingTaskGroup(of: Result.self) { group in
        for item in items { group.addTask { try await self.work(item) } }
        var results: [Result] = []
        for try await r in group { results.append(r) }
        return results
    }
}
```

## Optional Handling

### Guard let — early return

```swift
func process(_ data: Data?) throws -> Output {
    guard let data, !data.isEmpty else { throw ProcessError.invalid }
    return try parse(data)
}
```

### Nil coalescing

```swift
let language = settings.language ?? "en"
let timeout = config.timeout ?? 30.0
```

### Force-unwrap is forbidden, with two narrow exceptions

```swift
// Forbidden
let value = optional!

// Exception 1: provably non-nil constant, with a comment naming the invariant
let url = URL(string: "https://example.com")! // static URL literal

// Exception 2: test code where a failure is the assertion
let result = try! sut.process(input)
```

## Error Handling

### Custom error with localized descriptions

```swift
enum ServiceError: LocalizedError {
    case notFound
    case upstreamFailure(Error)
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .notFound: return "Resource not found"
        case .upstreamFailure(let e): return "Upstream failure: \(e.localizedDescription)"
        case .quotaExceeded: return "Quota exceeded"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .quotaExceeded: return "Try again later"
        default: return nil
        }
    }
}
```

### Catch by type

```swift
do {
    let result = try await service.run()
    handle(result)
} catch let error as ServiceError {
    handleServiceError(error)
} catch {
    handleUnknownError(error)
}
```

### Result for synchronous validation

```swift
func validate(_ input: String) -> Result<Token, ValidationError> {
    guard !input.isEmpty else { return .failure(.empty) }
    return .success(Token(input))
}
```

## Memory Management

### Capture lists

```swift
// Closures — capture self weakly when the closure outlives self's natural scope
service.fetch { [weak self] result in
    guard let self else { return }
    self.handle(result)
}

// Tasks — same rule
Task { [weak self] in
    guard let self else { return }
    await self.run()
}
```

### Delegate is `weak`

```swift
protocol DownloadDelegate: AnyObject {
    func downloadDidFinish(_ download: Download)
}

final class Download {
    weak var delegate: DownloadDelegate?
}
```

## Value vs. Reference Types

### Default to `struct`

```swift
struct UserProfile {
    let id: String
    let name: String
    let email: String
}
```

### Use `class` only when one of these holds

- Shared mutable state with identity semantics
- Reference equality matters (`===`)
- Inheritance is required (e.g., subclassing a framework class)
- Lifecycle matters (deinit hooks)

## Sendable & Actor

### Sendable for cross-actor data

```swift
struct Config: Sendable {
    let endpoint: URL
    let timeout: TimeInterval
}
```

### Actor for serialized state

```swift
actor RequestCounter {
    private var count = 0
    func increment() { count += 1 }
    func current() -> Int { count }
}

await counter.increment()
```

## Checklist

- [ ] async/await over completion handlers
- [ ] guard for early return; no nested `if let`
- [ ] No force-unwrap outside the two named exceptions
- [ ] `[weak self]` in closures and Tasks that may outlive self
- [ ] `struct` by default; `class` only with a stated reason
- [ ] Delegates declared `weak`
- [ ] `@MainActor` on UI-touching types or explicit `MainActor.run` hops
