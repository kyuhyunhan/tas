---
name: ref-apple-security
description: Apple-platform security guidelines — Keychain for sensitive client data, App Transport Security, sandboxing and entitlements, log masking, input validation at the boundary. Invoke when designing or reviewing security-sensitive code on iOS/macOS. Do NOT invoke for server-side security (use a server-security skill) or for cryptographic primitive selection.
version: 1.0.0
metadata:
  domain: apple-platform
---

# Apple Platform Security

Client-side security baseline for iOS and macOS apps.

## Principles

1. **Least privilege** — request only the entitlements and permissions the feature actually needs.
2. **Defense in depth** — assume any single layer can fail; design so one breach is not catastrophic.
3. **Secure by default** — the default code path is the safe one; opt out, never opt in.
4. **Fail secure** — on error, fall back to the more restrictive state, not the more permissive one.

## Sensitive data — Keychain

Sensitive client-side data lives in Keychain. `UserDefaults` is for non-sensitive preferences only.

```swift
// Good
let token = KeychainStorage.shared.retrieve(key: "auth_token")

// Bad — UserDefaults is plaintext on disk
let token = UserDefaults.standard.string(forKey: "auth_token")

// Bad — never hard-code secrets
let apiKey = "sk-1234567890"
```

### What goes where

| Data class | Storage | Why |
|------------|---------|-----|
| Auth tokens, license keys | Keychain | Sensitive, must persist across launches |
| Stable device identifier | Keychain | Survives app reinstall via `kSecAttrAccessibleAfterFirstUnlock` |
| Server-side API keys | Server only | Never on the client |
| User preferences (theme, language) | UserDefaults | Non-sensitive |
| User-generated content | App-managed store (SwiftData / Core Data / files) | Volume + queryability |

## Transport security

```
Required:
- All network traffic over HTTPS (TLS 1.2 minimum)

Forbidden:
- Plain HTTP for any user-facing or auth-bearing traffic
- Self-rolled cryptographic protocols
```

### App Transport Security

Keep ATS at its default (HTTPS-only, modern TLS). Do not add `NSAllowsArbitraryLoads` or per-domain exceptions without a documented, time-bounded reason.

```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <!-- defaults — do not weaken -->
</dict>
```

## Sandboxing & entitlements

Enable the App Sandbox on macOS. Add only the entitlements the app uses:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>

<key>com.apple.security.network.client</key>
<true/>
```

A useful audit: list every entitlement and write the *single feature* that requires it. If any entitlement has no answer, remove it.

| Entitlement | Required for |
|-------------|--------------|
| `network.client` | Outbound HTTPS |
| `screen-recording` (Privacy permission) | Screen capture |
| `accessibility` (Privacy permission) | Global hotkeys, AX inspection |

If a permission's answer is "we might need it later" — remove it now, add it when the feature ships.

## Input validation

Validate at the **boundary** (where untrusted input enters), not deep inside. Validate length, charset, structure — the smallest set that lets the rest of the code trust the input.

```swift
// Boundary check
func validateUserInput(_ text: String) -> Bool {
    return !text.isEmpty && text.count <= 10_000
}

// Format check on a specific shape
func validateLicenseKey(_ key: String) -> Bool {
    let pattern = "^[A-F0-9]{8}-[A-F0-9]{8}$"
    return key.range(of: pattern, options: .regularExpression) != nil
}
```

## Logging

```
Log:
- Authentication attempts (success / failure, never the credential)
- Authorization denials
- Request metadata (path, status, duration)

Never log:
- Tokens, license keys, API keys (mask if absolutely needed for debugging)
- Personally identifiable information (email, name, device fingerprints)
- User-generated content (translations, messages, file contents)
```

### Masking helper

```swift
func mask(_ secret: String) -> String {
    guard secret.count > 8 else { return "***" }
    return "\(secret.prefix(4))…\(secret.suffix(4))"
}

Log.info("License validation: \(mask(licenseKey))")
```

## Release checklist

- [ ] No secrets hard-coded in client binary (`strings App.app/Contents/MacOS/App | grep -E '^(sk_|api_|secret_)'` returns nothing)
- [ ] Sensitive data lives in Keychain
- [ ] HTTPS only; no ATS exceptions
- [ ] All entitlements justified by a current feature
- [ ] No sensitive data in logs (sample OSLog stream during a typical session)
- [ ] Hardened Runtime enabled
- [ ] Code-signed and notarized for distribution
