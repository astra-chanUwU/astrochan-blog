---
title: "TypeScript at the Boundary"
description: "Types become useful when untrusted data first enters a program."
date: 2026-09-08
slug: "typescript-at-the-boundary"
demo: true
toc: true
tags:
  - demo
  - typescript
  - javascript
---

TypeScript is excellent at remembering facts that our program has already
proved. It is much less magical at the places where facts are still unknown:
JSON responses, browser storage, environment variables, message events, and
third-party callbacks.

Those edges are where I want the most friction. Inside the application, types
should make ordinary work calm. At the boundary, they should make uncertainty
impossible to ignore.

## The comfortable lie

Here is a familiar helper:

```typescript
type Session = {
  userId: string;
  expiresAt: number;
};

async function loadSession(): Promise<Session> {
  const response = await fetch('/api/session');
  return response.json();
}
```

The return type looks reassuring, but nothing checked the response. The server
can return an error document, an older payload, or valid JSON with the wrong
shape. `response.json()` contributes `any`, and `any` quietly agrees to become
`Session`.

The annotation documents a hope. It does not establish a fact.

### The same problem in JavaScript

JavaScript does not pretend the runtime value is safer than it is:

```javascript
export async function loadSession() {
  const response = await fetch('/api/session');
  return response.json();
}
```

This version is not inherently less reliable. Both functions trust the same
network response. TypeScript merely gives us tools to make that trust explicit.

## `unknown` is a useful speed bump

The smallest improvement is to erase the accidental `any`:

```typescript
async function readJson(response: Response): Promise<unknown> {
  return response.json();
}

const payload = await readJson(response);

// Property 'userId' does not exist on type 'unknown'.
console.log(payload.userId);
```

`unknown` does not mean the value is unusable. It means every use must be
preceded by evidence. A `typeof` check, an array check, or a purpose-built
decoder can provide that evidence.

{{< notice type="note" label="Boundary rule" >}}
Use strict validation where data enters the application. Do not scatter
defensive optional chaining through every component that consumes it.
{{< /notice >}}

## Begin with small predicates

A few narrow helpers are enough for many payloads:

```typescript
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isString(value: unknown): value is string {
  return typeof value === 'string';
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}
```

The return type `value is string` is a type predicate. When the function returns
true, TypeScript carries that fact into the guarded branch.

### Decode the object once

We can combine those predicates into a decoder:

```typescript
function decodeSession(value: unknown): Session {
  if (!isRecord(value)) {
    throw new TypeError('Session must be an object');
  }

  if (!isString(value.userId)) {
    throw new TypeError('Session.userId must be a string');
  }

  if (!isFiniteNumber(value.expiresAt)) {
    throw new TypeError('Session.expiresAt must be a finite number');
  }

  return {
    userId: value.userId,
    expiresAt: value.expiresAt,
  };
}
```

After `decodeSession` returns, the rest of the application can accept a real
`Session`. The uncertainty has been handled once, close to its source.

## Make failure part of the API

Throwing is useful when malformed data means the current operation cannot
continue. For expected failure, a result type makes both paths visible:

```typescript
type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; error: E };

type DecodeError = {
  path: string;
  expected: string;
  received: unknown;
};
```

The `ok` field is a discriminant. Checking it narrows the entire union rather
than one property at a time.

```typescript
function decodeSession(value: unknown): Result<Session, DecodeError> {
  if (!isRecord(value)) {
    return {
      ok: false,
      error: { path: '$', expected: 'object', received: value },
    };
  }

  if (!isString(value.userId)) {
    return {
      ok: false,
      error: {
        path: '$.userId',
        expected: 'string',
        received: value.userId,
      },
    };
  }

  if (!isFiniteNumber(value.expiresAt)) {
    return {
      ok: false,
      error: {
        path: '$.expiresAt',
        expected: 'finite number',
        received: value.expiresAt,
      },
    };
  }

  return {
    ok: true,
    value: { userId: value.userId, expiresAt: value.expiresAt },
  };
}
```

At the call site, forgetting the error path becomes difficult:

```typescript
const decoded = decodeSession(await readJson(response));

if (!decoded.ok) {
  console.warn(`Invalid value at ${decoded.error.path}`);
  return null;
}

return decoded.value;
```

## Fetch should have an opinion

A useful request helper distinguishes HTTP failure, invalid JSON, invalid data,
and cancellation. These failures have different meanings to the interface.

```typescript
class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly url: string,
  ) {
    super(`Request failed with status ${status}`);
  }
}

async function fetchSession(signal?: AbortSignal): Promise<Session> {
  const response = await fetch('/api/session', {
    headers: { accept: 'application/json' },
    signal,
  });

  if (!response.ok) {
    throw new HttpError(response.status, response.url);
  }

  return decodeSessionOrThrow(await readJson(response));
}
```

Passing `AbortSignal` through the helper lets the caller own the operation's
lifetime. A component can stop obsolete work without teaching the fetch helper
anything about components.

### Cancellation belongs to the caller

```typescript
const controller = new AbortController();

fetchSession(controller.signal)
  .then(renderSession)
  .catch((error: unknown) => {
    if (error instanceof DOMException && error.name === 'AbortError') return;
    renderFailure(error);
  });

window.addEventListener('pagehide', () => controller.abort(), { once: true });
```

The caller decides when the answer is no longer useful. The request code only
honors that decision.

## Browser storage is an external system

`localStorage` lives in the same browser, but its values can outlive several
versions of the application. Treat it like an old API response.

```typescript
function readStoredSession(key = 'session'): Session | null {
  const source = localStorage.getItem(key);
  if (source === null) return null;

  try {
    return decodeSessionOrThrow(JSON.parse(source));
  } catch {
    localStorage.removeItem(key);
    return null;
  }
}
```

Deleting malformed state is a product decision. A draft editor might preserve
and migrate it; an expired session token can usually be discarded.

### Version data that must survive

```typescript
type StoredPreferences =
  | { version: 1; compact: boolean }
  | { version: 2; density: 'comfortable' | 'compact' };

function migratePreferences(value: StoredPreferences): StoredPreferences {
  switch (value.version) {
    case 1:
      return {
        version: 2,
        density: value.compact ? 'compact' : 'comfortable',
      };
    case 2:
      return value;
  }
}
```

The exhaustive switch turns forgotten migrations into compiler errors when a
new version joins the union.

## JavaScript can keep the contract too

JSDoc provides useful checking when converting a file to TypeScript would add
more ceremony than value:

```javascript
// @ts-check

/**
 * @typedef {{ userId: string, expiresAt: number }} Session
 */

/**
 * @param {unknown} value
 * @returns {Session}
 */
export function decodeSession(value) {
  if (!value || typeof value !== 'object') {
    throw new TypeError('Expected a session object');
  }

  const candidate = /** @type {Record<string, unknown>} */ (value);

  if (typeof candidate.userId !== 'string') {
    throw new TypeError('Expected userId to be a string');
  }

  if (typeof candidate.expiresAt !== 'number') {
    throw new TypeError('Expected expiresAt to be a number');
  }

  return {
    userId: candidate.userId,
    expiresAt: candidate.expiresAt,
  };
}
```

The runtime checks are still the source of truth. JSDoc lets the editor remember
their result for the code that follows.

## Configuration without widening

The `satisfies` operator checks a value while preserving its precise literals:

```typescript
type RuntimeConfig = {
  endpoint: URL;
  retries: 0 | 1 | 2 | 3;
  mode: 'development' | 'production';
};

const config = {
  endpoint: new URL('/api/', window.location.origin),
  retries: 2,
  mode: 'development',
} satisfies RuntimeConfig;

// Preserved as the literal type "development".
config.mode;
```

An `as RuntimeConfig` assertion would silence useful detail. `satisfies` asks the
compiler to check compatibility without replacing the inferred type.

## Concurrent work needs individual outcomes

`Promise.all` is correct when one failure invalidates the whole operation. When
each request can contribute independently, preserve each outcome instead:

```typescript
const requests = userIds.map((userId) => fetchUser(userId));
const outcomes = await Promise.allSettled(requests);

const users = outcomes.flatMap((outcome) =>
  outcome.status === 'fulfilled' ? [outcome.value] : [],
);

const failures = outcomes.flatMap((outcome) =>
  outcome.status === 'rejected' ? [outcome.reason] : [],
);
```

This is another boundary: rejected promises contain `unknown` reasons in
practice, even when older library types suggest `any`. Normalize those reasons
before displaying or reporting them.

```typescript
function errorMessage(reason: unknown): string {
  if (reason instanceof Error) return reason.message;
  if (typeof reason === 'string') return reason;

  try {
    return JSON.stringify(reason);
  } catch {
    return 'Unknown error';
  }
}
```

## Test the contract with ugly values

Happy-path fixtures prove very little about a decoder. The useful examples are
values that are almost valid:

```typescript
import { describe, expect, it } from 'vitest';

describe('decodeSession', () => {
  it.each([
    null,
    [],
    { userId: 42, expiresAt: 1_800_000_000 },
    { userId: 'aya', expiresAt: Number.NaN },
    { userId: 'aya' },
  ])('rejects %j', (value) => {
    expect(decodeSession(value).ok).toBe(false);
  });

  it('returns a session after every field is established', () => {
    expect(decodeSession({ userId: 'aya', expiresAt: 1_800_000_000 })).toEqual({
      ok: true,
      value: { userId: 'aya', expiresAt: 1_800_000_000 },
    });
  });
});
```

Tests like these document the boundary more honestly than a large snapshot. A
future refactor can change the decoder's internals while preserving the facts it
promises to establish.

## The quiet interior

Once a boundary returns `Session`, internal code should accept that type without
revalidating it. Repeated checks are usually a sign that untrusted and trusted
values share the same path.

The useful rhythm is simple:

1. receive an `unknown` value;
2. establish its structure once;
3. return a narrow type or an explicit failure;
4. let ordinary application code trust the result.

TypeScript is most pleasant after the proof. The boundary is where we earn that
pleasantness.
