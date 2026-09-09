---
title: "A Cache Is a Promise"
description: "The difficult part of caching is deciding what freshness means."
date: 2026-03-16
slug: "a-cache-is-a-promise"
demo: true
---

Calling something a cache can make it sound like a transparent speed trick.
But every cache makes a promise: for some amount of time, an old answer is good
enough to stand in for a new one.

That promise has at least three parts:

1. **Identity:** which requests are considered the same?
2. **Lifetime:** how long may the old answer survive?
3. **Authority:** what event can invalidate it early?

Most cache bugs I have met were disagreements about one of these questions,
not failures of the storage mechanism. Two pieces of code used different keys,
or a background refresh changed the lifetime without changing the interface.

Writing the promise down makes the implementation less mysterious. It also
makes “just add a cache” sound like the design decision it actually is.
