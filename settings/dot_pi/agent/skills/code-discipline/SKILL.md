
---
name: code-discipline
description: "Coding doctrine for implementation agents: produce the most result with the least code, make the type system do the proof work, keep the diff small and maintainable. Read this before writing any non-trivial code — it is required reading for ICs dispatched by ic-orchestrator, and applies any time you implement typed code."
metadata:
  version: "1"
---

# Your discipline and focus

Writing code is cheap for you, which makes over-engineering easy. Counter it by borrowing a human maintainer's fatigue. Aim for the most result with the least code and complexity.

## The patterns

- The type checker is a proof assistant. Use it to eliminate impossible states, mismatched primitives, and unhandled variants at compile time. A case the types let you ignore becomes a runtime failure the compiler could have stopped. Prefer defining errors and special cases out of existence over proliferating handlers; unrepresentable states, total functions, and interface redesign (the patterns below) are the tools.
- Make illegal states unrepresentable. Model variants as sum types: discriminated unions in TypeScript, enums with payloads in Rust/Swift/Kotlin, sealed classes in Scala, ADTs in Haskell/OCaml. Don't model state as a bag of optional fields where contradictory combinations compile. A subtle anti-pattern worth naming: { completed: boolean; completedAt?: Date } admits completed: true; completedAt: undefined, which is meaningless. Derive the boolean from a single source like completedAt !== null, or model the variants explicitly as { kind: 'open' } | { kind: 'done'; at: Date }. If a bug forces the question "wait, can this combination actually happen?", the type is too loose.
- Types are constructions, not restrictions. Build the type up from the values you want instead of carving them out of a looser type with checks. The invariant that seems to need a refinement type is usually a construction away. A non-empty list is a head plus a rest, not a list with a length check. A valid time range is a start plus a duration, not two timestamps you must keep ordered. No representation is privileged. A list of pairs is an even-length list if you interpret it that way, so choose the shape that cannot build the illegal value and expose the interface callers need on top.
- Brand semantic primitives. UserId and OrderId are strings underneath but should not be interchangeable. Newtypes in Rust, opaque types in Swift, value classes in Kotlin, phantom types in Haskell, branded intersections in TypeScript. Validate once at creation, trust the type downstream.
- External data is untyped until parsed. RPC payloads, JSON, IPC messages, CLI args, config files, environment variables, database rows. Have a parse function at every boundary that turns unstructured input into the typed model. See the boundary-discipline principle skill for where to put validation.
- Don't lie to the type system. Casts, unsafe coercions, and assertion functions that bypass the compiler are runtime crashes waiting to happen. If the compiler can't prove a fact, prove it (validate, narrow, refine the model) or accept that the cast is a hazard. The cast you bury today is the postmortem you write next week.
- Exhaustive matching is the compiler's job. When you match on a sum type, the compiler must fail compilation if a new variant is added without handling. Use the idiom your language provides: never-typed binding in TypeScript, unannotated match in Rust, -Wincomplete-patterns in Haskell, sealed-class match exhaustiveness in Kotlin.
- Derive types from authoritative schemas. When a protocol buffer, OpenAPI spec, GraphQL schema, database migration, or design-system token file defines a shape, derive from it instead of hand-rolling a parallel type. Manual duplication drifts. See the encode-lessons-in-structure principle skill.
- Strengthen a type only where partiality appears. A runtime assertion, null check, or "this should never happen" throw marks the place a type is too weak. Push that check up into the type. Then stop. The type system's job is to track the cases each use site must handle, not to describe the data as precisely as possible. Prefer total functions. sum of an empty list is 0, so it takes the plain list. head of an empty list has no answer, so it demands the non-empty one. Extra precision costs reuse and ceremony and buys no safety.

## What to watch for

- "Can I write a comment explaining when this combination of fields is valid?" If yes, the type is too loose. Split it into a sum type.
- "Do two of my function arguments share a primitive type but mean different things?" Brand them.
- "Where did this any, this as, this assertNotNull come from?" Trace it to the boundary and validate there instead.
- "If a new variant is added next month, will the compiler tell the next agent where to add a case?" If no, the match isn't exhaustive.
- "Is this type duplicating a shape another file owns?" Derive instead.
- "Am I strengthening this type to keep an operation total, or just to be more precise?" If nothing would otherwise panic, keep the plain type.

## How to think

- Data structures first. Get the data shape right before writing logic. The right shape makes downstream code obvious. Define core types early, trace every access pattern, and choose structures that match the dominant paths. A data-structure change late is a rewrite. Early, it is often a one-line diff.
- At code level, DRY the structure, not every line. Types and data models should converge. Three similar statements still beat a premature abstraction. Prefer explicit over clever. Test behavior and edge cases, not line counts.
- Each increment should land a coherent abstraction or deepen one that exists. Do not spread a new capability across callers as special-case coordination.
- Subtraction comes before scaffolding: remove dead weight first, then lay foundations.
- If something helps every later phase, do it first. Ask "does every subsequent phase benefit from this existing?" CI, linting, test infrastructure, and shared types are scaffold. Sequence for option value: setup before features, tests before fixes. Keep commits small and single-purpose (when you own git — under an orchestrator you don't; it commits for you).
- Prefer deletion. When asked to refactor or improve, look for removals before additions.
- Maintain a flat call hierarchy. Avoid deep call chains. A rich interface that hides substantial work is not a deep call chain. If answering a question requires tracing through more than 3 files or layers, flatten it.
- Consolidate decisions. Do not repeat the same choice in several places. Put it behind one source of truth and pass the result as a simple flag.
- Minimize the diff. Make the smallest change that solves the problem. Fewer lines beat "elegant" boilerplate.
- Question the threading. If a task asks you to pass a new signal through types, schemas, pipelines, or similar layers, stop and look for a more direct path.
- Sweat the small leaks. Remove tiny pass-throughs, representation leaks, and duplicated choices before they spread. Small leaks compound into permanent coordination costs.
- Prime directive: If a human developer would find the code exhausting to maintain, it is a bad solution. Stay simple.