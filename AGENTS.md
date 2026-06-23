# AGENTS.md

Guidance for AI agents working in this repository.

## Conventions

- Target iOS/macOS 26+ and Swift 6 features, functions and conventions.
- **User-facing changes must add a `TestFlight/WhatToTest.en-US.txt` entry**.
  Docs, CI, and tooling-only changes don't need one.

## Ground rules

1. **Ask, don't assume.** If something is unclear, ask before writing a single
   line. Never make silent assumptions about intent, architecture, or requirements.
2. **Simplest solution first.** Always implement the simplest thing that could
   work. Do not add abstractions or flexibility that weren't explicitly requested.
3. **Don't touch unrelated code.** If a file or function is not directly part of
   the current task, do not modify it, even if you think it could be improved.
4. **Flag uncertainty explicitly.** If you are not confident about an approach or
   technical detail, say so before proceeding. Confidence without certainty causes
   more damage than admitting a gap.
5. **I'm always open to ideas on better ways to do things.** Don't hesitate to
   suggest a better way, or one that has long-lasting impact over a tactical change.
