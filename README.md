# gen-algebra — pure algebraic primitives for Nix

[![CI](https://github.com/sini/gen-algebra/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-algebra/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

Foundational primitives for the gen family: a Palmer §3 search monad, intensional functions, standalone identity hashing, record algebra with scoped labels, and Either combinators.

**Class A (pure, zero-input).** gen-algebra declares no flake inputs and depends on nothing — not even nixpkgs `lib`; it is `builtins`-only and sits at the pure-algebra root of the ecosystem. A CI purity invariant (`ci/tests/purity.nix`) enforces this: any stray `lib.types` / `mkOption` / `evalModules` in the library source fails the suite.

## Table of Contents

- [Overview](#overview)
- [Gen Ecosystem](#gen-ecosystem)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Demo](#demo)
- [Architecture](#architecture)
- [Testing](#testing)
- [Theoretical Foundations](#theoretical-foundations)

## Overview

gen-algebra is a fully pure Nix library — zero dependencies, `builtins` only. Search monad for indexed state threading with convergence. Intensional function constructors for conservative equality (Palmer §2.2-2.3). Record algebra with scoped labels (Leijen §2) and mixin composition (Bracha §2-4). Either combinators. Standalone identity hashing.

The module-system tier (identity/strict/validators/cross-registry refs for `lib.evalModules`) **relocated to [gen-schema](https://github.com/sini/gen-schema)**, its sole consumer; gen-algebra is the ecosystem's pure-algebra root. Its former `pure` tier is now simply the `lib` output — everything gen-algebra ships is pure.

### Extraction Lineage

```
flake-aspects ──→ gen-algebra.search, gen-algebra.mkIntensional, gen-algebra.intensionalEq
                    ↓
              gen-schema (typed registries on gen-algebra primitives;
                          owns the module-system tier — identity/strict/validators/refs)
                    ↓
              gen-aspects (aspect composition on gen-algebra + gen-schema)
                    ↓
                   den (system configuration framework)
```

gen-algebra has zero flake inputs — this lineage shows where each primitive was extracted from and who consumes gen-algebra downstream, not runtime dependencies.

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-prelude](https://github.com/sini/gen-prelude) | Pure nixpkgs-lib-free utility base (builtins re-exports + vendored lib utils) |
| [gen-algebra](https://github.com/sini/gen-algebra) | **This lib** — Pure primitives (record, search monad, either, intensional identity) |
| [gen-types](https://github.com/sini/gen-types) | Clean-room MIT structural type checker (leaf/poly checkers; `verify: v → null\|err`) |
| [gen-merge](https://github.com/sini/gen-merge) | Byte-mode module merge engine (`evalModuleTree`, byte-identical to nixpkgs `lib.evalModules` over the priority subset) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (kinds, instances, collections, refs); re-hosted on gen-merge |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect type system (traits, classification, dispatch); re-hosted on gen-merge |
| [gen-scope](https://github.com/sini/gen-scope) | HOAG scope-graph evaluator (demand-driven, \_eval memoization, circular attributes) |
| [gen-graph](https://github.com/sini/gen-graph) | Accessor-based graph query combinators (traversal, condensation, phaseOrder) |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (pattern matching over graph positions) |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding (inject external args into NixOS modules) |
| [gen-dispatch](https://github.com/sini/gen-dispatch) | Relational rule dispatch STEP (stratified phases, conflict resolution) |
| [gen-resolve](https://github.com/sini/gen-resolve) | Demand-driven RAG evaluator over scope graphs (attribute schedule + convergence loop) |
| [gen-memo](https://github.com/sini/gen-memo) | The incremental plane — decides reuse, never evaluates (change propagation, AFFECTED set) |
| [gen-vars](https://github.com/sini/gen-vars) | Pure-Nix vars/secrets (den-agnostic) |
| [gen-flake](https://github.com/sini/gen-flake) | The nixpkgs boundary — compose purely, inject resolved values, build NixOS systems (value-injection) |

## Quick Start

### As a flake input

```nix
{
  inputs.gen.url = "github:sini/gen-algebra";

  outputs = { gen, ... }:
    let
      # Fully pure — no lib needed. Everything is under the `lib` output.
      search = gen.lib.search;
      inherit (gen.lib)
        mkIntensional
        intensionalEq
        record
        either
        ;
    in
    { /* ... */ };
}
```

### Without flakes

```nix
let
  # Fully pure — no nixpkgs / lib needed. The non-flake entry (default.nix = import ./lib)
  # is the lib value itself, not a function — so no argument is applied.
  gen = import ./path/to/gen-algebra;
in
{
  inherit (gen) search record either mkIntensional;
}
# gen.search.empty, gen.record.fromAttrs, gen.either.right, … all `builtins`-only.
```

## API Reference

Every exported name is documented below, grouped by primitive family. The full surface is `search` (8), `record` (26), `either` (6), plus top-level `mkIntensional` and `intensionalEq` — verified against `nix eval .#lib`.

### Search Monad

An indexed state monad for monotonic data accumulation with continuation-driven convergence. Zero dependencies — pure `builtins`.

#### `empty`

Initial state with empty index, results, and continuations.

```nix
search.empty
# → { index = {}; results = []; continuations = []; }
```

#### `insert`

Add a value to a key in the index. Values accumulate — multiple inserts to the same key append.

```nix
s = search.insert "users" "alice" search.empty;
search.insert "users" "bob" s;
# index.users → [ "alice" "bob" ]
```

#### `lookup`

Retrieve values for a key. Returns `[]` for absent keys.

```nix
search.lookup "users" (search.insert "users" "alice" search.empty)
# → [ "alice" ]

search.lookup "missing" search.empty
# → []
```

#### `has`

Check if a key exists in the index.

```nix
search.has "users" (search.insert "users" "alice" search.empty)
# → true

search.has "users" search.empty
# → false
```

#### `emit`

Append items to the results list.

```nix
s = search.emit [ "a" "b" ] search.empty;
(search.emit [ "c" ] s).results
# → [ "a" "b" "c" ]
```

#### `foldl`

`builtins.foldl'` — thread state through a list of values.

```nix
search.foldl (acc: item:
  search.insert item true (search.emit [ item ] acc)
) search.empty [ "a" "b" "c" ]
# results → [ "a" "b" "c" ], index has "a", "b", "c"
```

#### `on`

Register a continuation that fires when a key has unprocessed values during `converge`.

```nix
s0 = search.insert "users" "alice" search.empty;
s1 = search.on "users" (name: s: search.emit [ "hello:${name}" ] s) s0;
(search.converge s1).results
# → [ "hello:alice" ]
```

#### `converge`

Fixed-point convergence: fires all registered continuations on unprocessed values, repeats until stable. Safety guard at 1000 iterations.

Continuations registered during convergence (via `on` inside a continuation body) fire in subsequent rounds. Intensional continuations (created with `mkIntensional`) with the same key watching the same index key are deduplicated.

```nix
# Multi-round: A inserts data, B watches data
s0 = search.insert "trigger" "go" search.empty;
s1 = search.on "trigger" (v: s: search.insert "data" "from-A" s) s0;
s2 = search.on "data" (v: s: search.emit [ "B-saw:${v}" ] s) s1;
(search.converge s2).results
# → [ "B-saw:from-A" ]
```

### Intensional Functions

Palmer §2.2-2.3: function wrappers with program-point identity. gen implements the *structure* of Palmer's intensional functions (the three eliminators below); equality is **name-only** — a deliberate over-approximation, see [`intensionalEq`](#intensionaleq).

#### `mkIntensional`

Create a callable attrset with a `name` for identity comparison and inspectable `closure`.

```nix
fn = mkIntensional "add1" {} (x: x + 1);
fn 5          # → 6 (callable via __functor)
fn.name       # → "add1" (program point identity)
fn.closure    # → {} (inspectable metadata)
```

#### `intensionalEq`

**Name-only** equality by program point — two functions with the same `name` are equal regardless of closure. This is a deliberate *over-approximation*: it is a **superset** of Palmer's conservative equality (§2.3 Fig 5, which also requires equal closures), declaring *more* pairs equal, not fewer. It is sound under the discipline that callers fold any distinguishing data into the `name` (e.g. `"myPolicy:${hostName}"`). Note `closure` here is *programmer-declared* inspect data, not the compiler-extracted environment Palmer's Theorem 1 assumes — so the theorem's soundness does not transfer; gen relies on the naming discipline instead.

```nix
a = mkIntensional "same" {} (x: x);
b = mkIntensional "same" { different = true; } (y: y);
intensionalEq a b  # → true (same name)

c = mkIntensional "other" {} (x: x);
intensionalEq a c  # → false (different name)
```

Intensional equality powers continuation dedup in `search.converge` — duplicate `mkIntensional` continuations watching the same index key fire only once.

### Record Algebra

A record algebra with scoped labels (Leijen §2) and mixin composition (Bracha §2-4). Records support duplicate labels via shadow stacks — extending with an existing label pushes a new value, restriction pops it, exposing the previous value.

All operations are in `gen-algebra.record` (import path) — or `inputs.gen-algebra.lib.record` via the flake output. Zero dependencies.

#### Representation

Records use an attrset-with-shadow-stack representation for O(1) select:

```nix
# Internal: { __entries = { label = [value-stack]; }; __order = [labels]; }
r = record.fromAttrs { port = 8080; hostname = "localhost"; };
record.select r "port"      # → 8080
record.emit r                # → { port = 8080; hostname = "localhost"; }
```

#### Core primitives (Leijen §2)

```nix
record.empty                         # empty record
record.extend r "x" 42              # push value onto label's stack
record.select r "x"                  # head of stack (throws if absent)
record.restrict r "x"               # pop head (no-op if absent)
record.has r "x"                     # bool: label present?
record.depth r "x"                   # stack depth (0 if absent)
```

#### Scoped labels

```nix
# Duplicate labels form a stack — restriction exposes previous values
base = record.fromAttrs { level = "info"; };
env  = record.extend base "level" "warn";
user = record.extend env "level" "debug";

record.select user "level"                                      # → "debug"
record.select (record.restrict user "level") "level"            # → "warn"
record.select (record.restrict (record.restrict user "level") "level") "level"  # → "info"
```

#### Conversion

```nix
record.emit r                  # → plain attrset (heads only)
record.emitAll r [ "validators" ]  # → full stacks for listed labels, heads for rest
record.fromAttrs { a = 1; }   # → record with single-element stacks
record.show r                  # → "{ x = [2, 1]; y = [3] }" (full stacks)
record.showCompact r           # → "{ x = 2; y = 3 }" (heads only)
```

#### Derived operations

```nix
record.update r "x" 99        # replace head (throws if absent — strict)
record.upsert r "x" 99        # insert-or-update (no error)
record.rename r "old" "new"   # move label
record.labels r                # label names in insertion order
```

#### Composition (Bracha §2-4)

```nix
# Left-biased combination (⊕): a's values shadow b's
record.combine a b

# Smalltalk direction: delta wins over parent
record.mixin delta parent      # → combine (delta parent) parent

# Beta direction: parent controls, delta extends
record.mixinBeta prefix suffix

# Associative mixin composition (⋆)
record.compose m1 m2           # → fun(i) m1(m2(i) ⊕ i) ⊕ m2(i)
```

#### Row compatibility

```nix
record.satisfies r [ "port" "hostname" ]      # → bool
record.assertSatisfies r [ "port" "hostname" ] # → r or throws with missing fields
```

#### `foldLayers`

Fold ordered layers with per-field merge strategies. Useful for composing configuration from multiple priority tiers (e.g. defaults, system, user overrides) where different fields need different merge semantics.

Pure — `builtins` only, no `lib` dependency.

```nix
record.foldLayers {
  strategies ? {};   # field name → "replace" | "append" | "recursive"
  defaults ? {};     # fallback values for fields absent from all layers
  layers ? [];       # list of attrsets, least-specific first (base before overrides, last wins)
}
```

**Strategy types:**

- **`"replace"`** (default) — last layer providing the field wins. CSS cascade order: later overrides earlier.
- **`"append"`** — list concatenation across all layers in order, starting from `defaults`. Result: `defaults ++ layer1 ++ layer2 ++ ...`
- **`"recursive"`** — nested attrset merge (`//`) across layers in order. Later layers override earlier keys.
- **`"semilattice-set"`** — list-valued fields merged by set-union: fold each layer's elements into the accumulator, skipping any already present (dedup by `builtins.elem`). Unlike the three above — which are *associative* but order-sensitive (`replace` and `append` both depend on layer order, `recursive` on override order) — set-union is **ACI**: **a**ssociative, **c**ommutative, and **i**dempotent. The result is the layers' elements viewed as a set, so it is invariant under layer reordering and under duplicate contributions. This is the join of a set-union join-semilattice (∪ over finite sets); it is the strategy that lets `foldLayersTraced` stand in for the "semi-naïve evaluation over a lattice" merge of Datafun (ICFP 2016) and Flix (PLDI 2016), where a relation's value is the least upper bound of its contributions rather than a last-writer-wins cell.

```nix
record.foldLayers {
  strategies = {
    tags = "append";
    settings = "recursive";
    # name uses default "replace"
  };
  defaults = {
    tags = [ "base" ];
    settings = { verbose = false; };
  };
  layers = [
    # layer 0: lower priority (system)
    { name = "default"; tags = [ "system" ]; settings = { verbose = true; pager = "less"; }; }
    # layer 1: highest priority (user)
    { name = "custom"; tags = [ "user" ]; settings = { color = true; }; }
  ];
}
# → {
#   name = "custom";                                     # replace: last layer wins
#   tags = [ "base" "system" "user" ];                   # append: defaults ++ layers in order
#   settings = { verbose = true; pager = "less"; color = true; };  # recursive: merge in order
# }
```

#### `foldLayersTraced`

Single-pass variant of `foldLayers` that also returns per-field provenance. Takes
additional `layerNames` (opaque labels aligned 1:1 with `layers`, least-specific
first), optional `defaultLabel`, and optional `entryTransform`; returns
`{ value; provenance; }` where `provenance.<field>` is an ordered list of
`{ layer; value; }` (default first when present, then each contributing layer).
Any value is admissible as a layer name; the fold stores each verbatim into
`provenance.<field>[].layer` and never reads one.
Powers settings stratification.

```nix
record.foldLayersTraced {
  strategies = { tags = "append"; };
  defaults = { tags = [ "base" ]; };
  layers = [ { tags = [ "system" ]; } { tags = [ "user" ]; } ];
  layerNames = [ "system" "user" ];
}
# → { value = { tags = [ "base" "system" "user" ]; };
#     provenance.tags = [ { layer = "default"; value = [ "base" ]; }
#                         { layer = "system"; value = [ "system" ]; }
#                         { layer = "user"; value = [ "user" ]; } ]; }
```

**The `value` agrees with `foldLayers` on the strategies both accept**, and only
there. Over `"replace"` — declared explicitly or reached by omission —
`"append"`, `"recursive"`, and a field carried by `defaults` alone, the two
return byte-identical values for the same `strategies`, `defaults` and `layers`;
the value-identity guards in `ci/tests/rec-fold-layers-traced.nix` hold exactly
that. They are **not** one primitive with two return shapes: `"semilattice-set"`
resolves here and `foldLayers` refuses it. Computing an expected value from the
untraced sibling is licensed on the shared domain and nowhere else.

##### `entryTransform` — refining the emission, per entry, on demand

`entryTransform` is an optional `field -> entry -> entry'` applied to every entry
of a field's chain, the default entry included. It is for a caller that wants a
*derived* reading of each entry — the entry's value under some substitution the
caller owns — to be emitted **by** the fold rather than re-mapped over its output
afterwards. The fold hands over the field name and learns nothing in return: the
transform is opaque to it, exactly as layer labels are.

```nix
record.foldLayersTraced {
  defaults = { font = "unset"; };
  layers = [ { font = "mono"; } ];
  layerNames = [ "host" ];
  entryTransform = field: entry: { inherit (entry) layer; resolved = lookup field entry.value; };
}
# → provenance.font = [ { layer = "default"; resolved = <thunk>; }
#                       { layer = "host";    resolved = <thunk>; } ]
```

**Non-interference.** Application is per entry and demand-driven (call-by-need,
Launchbury 1993 §2). Forcing a chain's spine, one entry's own transformed record,
or any sibling entry never applies the transform to another entry, and forcing
`.value` never applies it at all. So a transform that is lazy in its derived part
keeps a *diverging* entry — one whose refinement throws, because it points at
something absent — harmless to the rest of the trace: the chain still has a
length, the entry still reports which layer it came from, its siblings still
resolve. That property, not the hook, is the capability; it is what a
consumer-side `map` over the finished provenance cannot give you. Omitting
`entryTransform` emits the chain untransformed with no per-entry application.

#### Nested-layer variants

`flattenAttrs`, `unflattenAttrs`, and `foldNestedLayers` extend layer folding to
nested attrsets. `foldNestedLayers` is `foldLayers` for nested structures
(flatten → `foldLayers` → unflatten); `flattenAttrs`/`unflattenAttrs` are its
dot-separated-key flatten/rebuild primitives (`flattenAttrs` halts recursion at
fields whose strategy is `"recursive"`).

### Either Combinators

Short-circuit and accumulating error handling via `{ right = value; }` | `{ left = error; }`. Zero dependencies.

All operations are in `gen-algebra.either` (import path) — or `inputs.gen-algebra.lib.either` via the flake output.

#### `right` / `left`

Construct Either values.

```nix
either.right 42      # → { right = 42; }
either.left "oops"   # → { left = "oops"; }
```

#### `pipe`

Short-circuit chain: first `left` stops the pipeline.

```nix
either.pipe [
  (x: if x > 0 then either.right (x * 2) else either.left "must be positive")
  (x: if x < 100 then either.right x else either.left "too large")
] 5
# → { right = 10; }
```

#### `collectErrors`

Accumulate all errors without short-circuiting.

```nix
either.collectErrors [
  (x: if x > 0 then either.right x else either.left "must be positive")
  (x: if x > -3 then either.right x else either.left "must be > -3")
] (-5)
# → { left = [ "must be positive" "must be > -3" ]; }
```

#### `mapR`

Map over the `right` value, passing `left` through unchanged.

```nix
either.mapR (x: x + 1) (either.right 41)   # → { right = 42; }
either.mapR (x: x + 1) (either.left "err")  # → { left = "err"; }
```

#### `chain`

FlatMap on `right` — apply a function that returns a new Either.

```nix
either.chain (x: if x > 0 then either.right (x * 10) else either.left "neg") (either.right 3)
# → { right = 30; }
```

## Demo

See [`examples/demo/`](examples/demo/) for a self-contained example exercising search monad workflow, intensional dedup, record algebra, and either combinators.

```bash
cd examples/demo
nix eval --override-input gen-algebra ../.. .#searchResult
nix eval --override-input gen-algebra ../.. .#dedupResult
nix eval --override-input gen-algebra ../.. .#scopedLabels
nix eval --override-input gen-algebra ../.. .#eitherDemo
```

## Architecture

```
gen-algebra/
  default.nix              — non-flake entry (bare lib value: import ./lib, no argument)
  flake.nix                — flake output (single `lib` value, no __functor)
  lib/
    default.nix            — exports search + intensional + either + record
    search.nix             — Palmer §3 Search monad (8 public primitives)
    intensional.nix        — mkIntensional, intensionalEq
    either.nix             — Either combinators (right, left, pipe, collectErrors, mapR, chain)
    rec.nix                — Leijen §2 record algebra with scoped labels + Bracha §2-4 mixin composition + foldLayers
  ci/                      — nix-unit test suite (incl. the purity invariant)
  examples/
    demo/                  — self-contained demo (search + dedup + records + either)
```

gen-algebra is fully pure — zero dependencies of any kind, not even nixpkgs `lib`. The CI purity invariant (`ci/tests/purity.nix`) enforces this: a stray `lib.types` / `mkOption` / `evalModules` in the library source fails the suite. The module-system tier relocated to [gen-schema](https://github.com/sini/gen-schema), its sole consumer.

## Testing

Tests live in `ci/` and run under nix-unit (via `gen.lib.mkCi`). 127 test cases across 12 suites (`either`, `intensional`, `purity`, `rec-primitives`, `rec-derived`, `rec-row`, `rec-composition`, `rec-fold-layers`, `rec-fold-layers-traced`, `rec-nested-layers`, `search-primitives`, `search-converge`), including the purity invariant that fails on any stray `lib.types` / `mkOption` / `evalModules` in the library source. Requires nix-unit.

```bash
# all suites
nix flake check --override-input gen-algebra . ./ci

# one suite (nix-unit)
nix-unit --flake ./ci#tests.rec-composition --override-input gen-algebra .
```

## Theoretical Foundations

| Paper | Relationship | Used for |
|-------|-------------|----------|
| Palmer et al. (2024) [*Intensional Functions*](https://dl.acm.org/doi/10.1145/3689714) | Implements structure / informed by | Search monad with name-keyed continuation dedup (§3); the three intensional eliminators `__functor`/`name`/`closure` (§2.2-2.3). Equality + dedup are **name-only** — a deliberate over-approximation of Palmer's name+closure conservative equality (§2.3 Fig 5), not the Theorem-1 result (gen's `closure` is programmer-declared, not compiler-extracted). |
| Leijen (2005) [*Extensible Records with Scoped Labels*](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/scopedlabels.pdf) | Implements | Record algebra with extension/selection/restriction (§2), scoped labels via shadow stacks (§2.1-3.2), row compatibility checks (§3.1) |
| Bracha & Cook (1990) [*Mixin-Based Inheritance*](https://www.bracha.org/oopsla90.pdf) | Implements | Left-biased combination (§2.1 ⊕ operator), Smalltalk-direction mixin (§2.1), Beta-direction mixin (§2.2), associative mixin composition ⋆ (§4) |

**Implements** means the code directly realizes the paper's constructs (`lib/search.nix` + `lib/intensional.nix` for Palmer's search monad and intensional *structure*; `lib/rec.nix` for Leijen and Bracha). One caveat: gen's intensional *equality* is a name-only over-approximation, not a faithful realization of Palmer's name+closure conservative equality (§2.3 Fig 5 / Theorem 1) — see [Intensional Functions](#intensional-functions).
