<p align="right">
  <a href="https://github.com/sini/gen-algebra/actions"><img src="https://github.com/sini/gen-algebra/actions/workflows/test.yml/badge.svg" alt="CI Status"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/sini/gen-algebra" alt="License"/></a>
</p>

# gen-algebra — Generic Nix Infrastructure

Foundational primitives for the gen family: a Palmer §3 search monad, intensional functions, identity hashing, record algebra with scoped labels, validation, strict modules, and cross-registry references.

## Table of Contents

- [Overview](#overview)
- [Gen Ecosystem](#gen-ecosystem)
- [Quick Start](#quick-start)
- [Pure Tier](#pure-tier)
- [Module Tier](#module-tier)
- [Demo](#demo)
- [Architecture](#architecture)
- [Testing](#testing)
- [Theoretical Foundations](#theoretical-foundations)

## Overview

gen-algebra is a two-tier Nix library:

- **Pure tier** — zero dependencies, `builtins` only. Search monad for indexed state threading with convergence. Intensional function constructors for conservative equality (Palmer §2.2-2.3). Record algebra with scoped labels (Leijen §2) and mixin composition (Bracha §2-4). Either combinators. Standalone identity hashing.
- **Module tier** — takes `{ lib }` from nixpkgs. Identity hashing, validators, strict freeform rejection, and cross-registry reference types for the NixOS module system.

### Extraction Lineage

```
flake-aspects ──→ gen-algebra.search, gen-algebra.mkIntensional, gen-algebra.intensionalEq
den-schema   ──→ gen-algebra.mkIdentityModule, gen-algebra.mkValidator, gen-algebra.mkStrictModule, gen-algebra.mkRefType
                    ↓
              gen-schema (typed registries on gen-algebra primitives)
                    ↓
              gen-aspects (aspect composition on gen-algebra + gen-schema)
                    ↓
                   den (system configuration framework)
```

gen-algebra has zero flake inputs — this lineage shows where each primitive was extracted from and who consumes gen-algebra downstream, not runtime dependencies.

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-algebra](https://github.com/sini/gen-algebra) | Pure primitives (search, record, identity) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (kinds, instances, collections, refs) |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect types (traits, classification, dispatch) |
| [gen-graph](https://github.com/sini/gen-graph) | Graph queries (combinators, traversals, fixpoint) |
| [gen-scope](https://github.com/sini/gen-scope) | Scope graphs (construction, evaluation, resolution) |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (pattern matching over graph positions) |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding (inject args into NixOS modules) |
| [gen-derive](https://github.com/sini/gen-derive) | Rule dispatch (stratified phases, fixpoint, conflict resolution) |

## Quick Start

### As a flake input

```nix
{
  inputs.gen.url = "github:sini/gen-algebra";

  outputs = { gen, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      # Pure tier — no lib needed
      search = gen.pure.search;
      inherit (gen.pure) mkIntensional intensionalEq;

      # Full tier — pass lib for module primitives
      g = gen { inherit lib; };
      inherit (g) mkValidator runValidators mkIdentityModule;
    in
    { /* ... */ };
}
```

### Without flakes

```nix
let
  lib = (import <nixpkgs> {}).lib;

  # Full tier
  gen = import ./path/to/gen-algebra { inherit lib; };

  # Pure tier only (no nixpkgs needed)
  genPure = import ./path/to/gen-algebra {};
in
gen.search.empty        # works
gen.mkValidator         # works
genPure.search.empty    # works
genPure.mkValidator     # throws: "gen-algebra.mkValidator requires lib — call (import gen-algebra { inherit lib; })"
```

## Pure Tier

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

Palmer §2.2-2.3: function wrappers with program-point identity for conservative equality.

#### `mkIntensional`

Create a callable attrset with a `name` for identity comparison and inspectable `closure`.

```nix
fn = mkIntensional "add1" {} (x: x + 1);
fn 5          # → 6 (callable via __functor)
fn.name       # → "add1" (program point identity)
fn.closure    # → {} (inspectable metadata)
```

#### `intensionalEq`

Conservative equality by program point — two functions with the same `name` are considered equal regardless of closure contents.

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

All operations are in `gen-algebra.record` (or `gen-algebra.pure.record`). Zero dependencies.

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

### Either Combinators

Short-circuit and accumulating error handling via `{ right = value; }` | `{ left = error; }`. Zero dependencies.

All operations are in `gen-algebra.either` (or `gen-algebra.pure.either`).

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

### Standalone Identity

Palmer §2.2 program-point identity as a standalone hash. No module system dependency.

#### `mkIdentity`

```nix
mkIdentity { name = "host"; fields = { addr = "10.0.1.1"; }; }
# → "host:${sha256(toJSON { addr = "10.0.1.1"; })}"
```

## Module Tier

These primitives require `{ lib }` from nixpkgs. Accessing them without passing `lib` throws a clear error.

### `mkIdentityModule`

Injects `id_hash` (deterministic SHA-256) and `_identity.keys` into a NixOS module. Hash is computed from primitive options (str, int, bool), prefixed by kind name.

```nix
# Used inside mkInstanceType / lib.evalModules:
modules = [
  (mkIdentityModule "host")
  { options.name = lib.mkOption { type = lib.types.str; }; }
  { options.addr = lib.mkOption { type = lib.types.str; }; }
  { config.name = "igloo"; config.addr = "10.0.1.1"; }
];

# instance.id_hash → deterministic SHA-256 of "host|addr=10.0.1.1|name=igloo"
```

Three-layer key selection: explicit `_identity.keys` > per-option `identity = false` > auto-reflection of all non-internal primitives.

### `mkValidator` / `runValidators` / `formatErrors` / `defaultOnError`

Validation pipeline for instance registries.

```nix
validators = [
  (mkValidator "has-name"
    (x: x ? name && x.name != "")
    "must have a name")
  (mkValidator "positive-age"
    (x: x ? age && x.age > 0)
    "age must be positive")
];

# Pass:
runValidators "person" validators {
  alice = { name = "Alice"; age = 30; };
}
# → { right = { alice = { ... }; }; }

# Fail:
runValidators "person" validators {
  broken = { name = ""; age = -1; };
}
# → { left = [
#      { kind = "person"; name = "broken"; validator = "has-name"; message = "must have a name"; }
#      { kind = "person"; name = "broken"; validator = "positive-age"; message = "age must be positive"; }
#    ]; }

# Format errors for display:
formatErrors result.left
# → "  person 'broken': has-name — must have a name\n  person 'broken': positive-age — age must be positive"

# Throw on error:
defaultOnError result.left
# throws: "schema validation failed:\n  person 'broken': ..."
```

### `mkStrictModule`

Injects a freeform type that rejects undeclared keys with fix guidance.

```nix
modules = [
  (mkStrictModule "host")
  { options.addr = lib.mkOption { type = lib.types.str; }; }
  { config.addr = "10.0.1.1"; config.badKey = "x"; }
];
# throws: STRICT MODE: "badKey" is not declared on host.
#         Fix: schema.host.options.badKey = lib.mkOption { ... };
```

### `mkRefType`

Cross-registry reference type. Input: string key. Output: resolved instance. Throws on missing key.

```nix
# Given a registry of evaluated instances:
hosts = { igloo = { addr = "10.0.1.1"; }; iceberg = { addr = "10.0.2.1"; }; };

# Use in module options:
options.host = lib.mkOption {
  type = mkRefType hosts;
};
config.host = "igloo";

# Resolves to the full instance:
# config.host.addr → "10.0.1.1"
# config.host = "missing" → throws: reference 'missing' not found in instance registry
```

## Demo

See [`templates/demo/`](templates/demo/) for a self-contained example exercising search monad workflow, intensional dedup, record algebra, either combinators, and validation.

```bash
cd templates/demo
nix eval --override-input gen-algebra ../.. .#searchResult
nix eval --override-input gen-algebra ../.. .#dedupResult
nix eval --override-input gen-algebra ../.. .#validationPass
nix eval --override-input gen-algebra ../.. .#validationFail
```

## Architecture

```
gen-algebra/
  default.nix              — entry point ({ lib ? null }), two-tier dispatch
  flake.nix                — flake outputs (__functor + lib)
  pure/
    default.nix            — exports search + intensional + identity + either + record
    search.nix             — Palmer §3 Search monad (8 public primitives)
    intensional.nix        — mkIntensional, intensionalEq
    identity.nix           — mkIdentity (standalone hash)
    either.nix             — Either combinators (right, left, pipe, collectErrors, mapR, chain)
    rec.nix                — Leijen §2 record algebra with scoped labels + Bracha §2-4 mixin composition
  module/
    default.nix            — exports identity + validation + strict + ref
    identity.nix           — mkIdentityModule (id_hash via SHA-256)
    validate.nix           — mkValidator, runValidators, formatErrors, defaultOnError
    strict.nix             — mkStrictModule (strict freeform rejection)
    ref-type.nix           — mkRefType (cross-registry references)
  templates/
    ci/                    — nix-unit test suite
    demo/                  — self-contained demo (search + dedup + records + either + validation)
```

The pure tier has zero dependencies — consumers needing only search or intensional functions don't pull in nixpkgs. The module tier takes `{ lib }` for NixOS module system primitives. Accessing module-tier functions without `lib` throws with a clear message rather than silently being absent.

## Testing

Tests live in `templates/ci/` using nix-unit:

```bash
nix-unit --flake ./templates/ci#tests --override-input gen-algebra .
```

## Theoretical Foundations

| Paper | Relationship | What |
|-------|-------------|------|
| Palmer et al. (2024) [*Intensional Functions*](https://dl.acm.org/doi/10.1145/3689714) | Implements | Search monad with continuation dedup (§3), intensional identity via program-point + closure (§2.2-2.3), conservative equality (§5.3) |
| Leijen (2005) [*Extensible Records with Scoped Labels*](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/scopedlabels.pdf) | Implements | Record algebra with extension/selection/restriction (§2), scoped labels via shadow stacks (§2.1-3.2), row compatibility checks (§3.1) |
| Bracha & Cook (1990) [*Mixin-Based Inheritance*](https://www.bracha.org/oopsla90.pdf) | Implements | Left-biased combination (§2.1 ⊕ operator), Smalltalk-direction mixin (§2.1), Beta-direction mixin (§2.2), associative mixin composition ⋆ (§4) |

**Implements** means the code directly realizes the paper's constructs. All three papers have corresponding primitives in the codebase: `pure/search.nix` and `pure/intensional.nix` for Palmer, `pure/rec.nix` for Leijen and Bracha.
