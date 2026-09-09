---
title: "Reading a Log File Slowly"
description: "Treating logs as a sequence of claims instead of a wall of noise."
date: 2026-07-11
slug: "reading-a-log-file-slowly"
demo: true
---

A large log invites fast reading: search for `error`, jump to the last stack
trace, and form a theory. That works often enough to become a habit. It also
makes it easy to miss the first ordinary-looking line where the system stopped
behaving normally.

My more reliable approach is to turn the log into a timeline.

```text
10:42:03.112 request accepted       id=7f2
10:42:03.119 cache lookup           result=miss
10:42:03.184 upstream connected     attempt=1
10:42:33.185 upstream timed out     elapsed=30s
10:42:33.187 response sent          status=504
```

The final line reports the failure. The useful question begins three lines
earlier: why did a normal connection produce no progress for thirty seconds?

## Separate observations from guesses

I keep a tiny table while investigating:

| Kind | Example | Confidence |
| --- | --- | --- |
| Observation | The cache missed | Certain |
| Observation | The upstream accepted a connection | Certain |
| Inference | The upstream received the request | Unclear |
| Hypothesis | A proxy buffered the request body | Untested |

This prevents a plausible story from quietly turning into a fact. The table is
especially useful when several people are debugging together; anyone can point
to the exact step where their interpretation differs.

## Preserve the original order

Filtering is useful, but I save the unfiltered slice first. Context lines are
not decoration. A retry, a configuration reload, or a slow warning may explain
why the obvious error occurred.

Reading slowly does not mean reading everything. It means deciding what each
line proves before asking it to support a theory.
