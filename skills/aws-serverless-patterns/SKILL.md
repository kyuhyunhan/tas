---
name: aws-serverless-patterns
description: AWS Lambda design patterns — handler/service separation, cold-start optimization (lazy clients, bundle minification), layered error classes, central error handler, Secrets Manager with TTL cache, third-party API integration. Invoke when designing or reviewing AWS Lambda code. Do NOT invoke for non-AWS serverless (Cloudflare Workers, Vercel functions) or for non-serverless backends.
version: 1.0.0
metadata:
  domain: aws-serverless
---

# AWS Serverless Patterns

Conventions for AWS Lambda functions exposed via API Gateway. TypeScript examples; principles port to Python/Go.

## Lambda design

### Single Responsibility per function

```typescript
// Good — one Lambda, one purpose
// dictionary.ts  — looks up a word
// translate.ts   — translates text
// usage.ts       — reports usage

// Bad — monolith
// api.ts — handles everything
```

A monolithic Lambda inflates cold-start cost, blurs IAM scopes, and slows deploys.

### Handler / Service separation

```typescript
// handlers/dictionary.ts
export const handler: APIGatewayProxyHandler = async (event) => {
  // 1. Parse + validate (handler concern)
  const request = validateRequest(event, DictionaryRequestSchema);

  // 2. Delegate business logic (service concern)
  const service = new DictionaryService();
  const result = await service.lookup(request);

  // 3. Format response (handler concern)
  return formatResponse(200, result);
};
```

The handler is a thin adapter between API Gateway and the service. The service knows nothing about HTTP.

### Configuration via environment

```typescript
// Good
const STAGE = process.env.STAGE ?? 'dev';
const SECRET_NAME = process.env.UPSTREAM_SECRET_NAME!;

// Bad
const SECRET_NAME = 'my-app/upstream-key'; // hard-coded
```

## Cold-start optimization

### Lazy client initialization (module-scope cache)

```typescript
let upstreamClient: UpstreamClient | null = null;

async function getUpstreamClient(): Promise<UpstreamClient> {
  if (!upstreamClient) {
    const apiKey = await getSecret(process.env.UPSTREAM_SECRET_NAME!);
    upstreamClient = new UpstreamClient({ apiKey });
  }
  return upstreamClient;
}
```

Module-scope state survives across invocations on the same execution context — first request pays the init cost, subsequent requests don't.

### Bundle minification

```javascript
// esbuild.config.js
build({
  bundle: true,
  minify: true,
  treeShaking: true,
  external: ['@aws-sdk/*'], // included by Lambda runtime; don't ship duplicates
  platform: 'node',
});
```

## Error handling

### Layered error classes

```typescript
export class AppError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: Record<string, unknown>
  ) {
    super(message);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, fields?: Record<string, string>) {
    super(400, 'VALIDATION_ERROR', message, { fields });
  }
}

export class UpstreamError extends AppError {
  constructor(service: string, originalError?: string) {
    super(502, 'UPSTREAM_ERROR', `External service error: ${service}`, {
      service,
      original_error: originalError,
    });
  }
}
```

### Central error handler

```typescript
export function handleError(error: unknown): APIGatewayProxyResult {
  if (error instanceof AppError) {
    return {
      statusCode: error.statusCode,
      body: JSON.stringify({
        success: false,
        error: { code: error.code, message: error.message, details: error.details },
      }),
    };
  }

  // Unknown errors → opaque 500. Never leak stack traces or internal details.
  return {
    statusCode: 500,
    body: JSON.stringify({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Unexpected error' },
    }),
  };
}
```

### Map third-party SDK errors to your domain

```typescript
try {
  return await upstream.call(...);
} catch (error) {
  if (error instanceof Upstream.APIError) {
    throw new UpstreamError('upstream-name', error.message);
  }
  throw error;
}
```

The handler always sees domain errors; transport-specific errors stop at the service boundary.

## Secrets Manager with TTL cache

```typescript
const cache = new Map<string, { value: string; expiresAt: number }>();
const CACHE_TTL_MS = 5 * 60 * 1000;

const client = new SecretsManagerClient({});

export async function getSecret(name: string): Promise<string> {
  const hit = cache.get(name);
  if (hit && hit.expiresAt > Date.now()) return hit.value;

  const response = await client.send(new GetSecretValueCommand({ SecretId: name }));
  const value = response.SecretString!;
  cache.set(name, { value, expiresAt: Date.now() + CACHE_TTL_MS });
  return value;
}
```

Cache scope is the execution context. TTL is a defense against rotation lag.

## Lambda configuration

| Function shape | Memory | Timeout | Notes |
|----------------|--------|---------|-------|
| Calls a third-party API | 256 MB | 15 s | Network-bound; CPU rarely the bottleneck |
| Reads/writes DynamoDB only | 128 MB | 3 s | Tight latency budget |
| Processes payload (parse/transform) | 512 MB+ | tune | CPU-bound; benchmark memory tier |

Memory is also CPU and network bandwidth on Lambda — the cheapest tier is not always the cheapest run.

## Checklist

- [ ] Handler / service separation
- [ ] Configuration via environment, not hard-coded
- [ ] Module-scope client cache for upstream clients
- [ ] Bundled and minified deployment artifact
- [ ] Layered error classes; central handler returns consistent shape
- [ ] Third-party SDK errors mapped to domain errors at the service boundary
- [ ] Secrets pulled from Secrets Manager with TTL cache
- [ ] Memory and timeout sized to actual workload, not defaults
