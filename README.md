<p align="right">
  <a href="https://github.com/vic/gen/actions"><img src="https://github.com/vic/gen/actions/workflows/test.yml/badge.svg" alt="CI Status"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/vic/gen" alt="License"/></a>
</p>

# gen — Generic Nix Infrastructure

Foundational primitives for the gen family: a [Palmer §3 Search monad](https://dl.acm.org/doi/10.1145/3674634), intensional functions, identity hashing, validation, strict modules, and cross-registry references.

## Overview

gen is a two-tier Nix library:

- **Pure tier** — zero dependencies, `builtins` only. Search monad for indexed state threading with convergence. Intensional function constructors for conservative equality (Palmer §2.2-2.3). Primitives library with bit manipulation, wrapping arithmetic, and a reference xxh64 hash implementation.
- **Module tier** — takes `{ lib }` from nixpkgs. Identity hashing, validators, strict freeform rejection, and cross-registry reference types for the NixOS module system.

### Extraction Lineage

```
flake-aspects ──→ gen.search, gen.mkIntensional, gen.intensionalEq
den-schema   ──→ gen.mkIdentityModule, gen.mkValidator, gen.mkStrictModule, gen.mkRefType
                    ↓
              gen-schema (typed registries on gen primitives)
                    ↓
              gen-aspects (aspect composition on gen + gen-schema)
                    ↓
                   den (system configuration framework)
```

gen has zero flake inputs — this lineage shows where each primitive was extracted from and who consumes gen downstream, not runtime dependencies.

## Quick Start

### As a flake input

```nix
{
  inputs.gen.url = "github:vic/gen";

  outputs = { gen, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      # Pure tier — no lib needed
      search = gen.lib.search;
      inherit (gen.lib) mkIntensional intensionalEq;

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
  gen = import ./path/to/gen { inherit lib; };

  # Pure tier only (no nixpkgs needed)
  genPure = import ./path/to/gen {};
in
gen.search.empty        # works
gen.mkValidator         # works
genPure.search.empty    # works
genPure.mkValidator     # throws: "gen.mkValidator requires lib — call (import gen { inherit lib; })"
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

[Palmer §2.2-2.3](https://dl.acm.org/doi/10.1145/3674634): function wrappers with program-point identity for conservative equality.

#### `mkIntensional`

Create a callable attrset with a `key` for identity comparison and inspectable `closure`.

```nix
fn = mkIntensional "add1" {} (x: x + 1);
fn 5          # → 6 (callable via __functor)
fn.key        # → "add1" (program point identity)
fn.closure    # → {} (inspectable metadata)
```

#### `intensionalEq`

Conservative equality by program point — two functions with the same `key` are considered equal regardless of closure contents.

```nix
a = mkIntensional "same" {} (x: x);
b = mkIntensional "same" { different = true; } (y: y);
intensionalEq a b  # → true (same key)

c = mkIntensional "other" {} (x: x);
intensionalEq a c  # → false (different key)
```

Intensional equality powers continuation dedup in `search.converge` — duplicate `mkIntensional` continuations watching the same index key fire only once.

### xxh64

A complete, spec-compliant [xxHash64](https://github.com/Cyan4973/xxHash) implementation in pure Nix. Provided as a reference and demonstration of Nix as a general-purpose language — production identity hashing uses `builtins.hashString "sha256"` instead (a C builtin, ~20x faster for short inputs).

```nix
gen.xxh64 "hello"        # → "26c7827d889f6da3"
gen.xxh64WithSeed 42 ""  # → seeded variant
```

All 21 test vectors match the official `xxhsum` reference implementation. The implementation demonstrates:

- **Split `{hi, lo}` representation** — keeps 64-bit values as two non-negative 32-bit halves, eliminating sign-bit handling from the hot path
- **Constant-specialized multiplies** — xxh64 prime constants pre-split into 16-bit quarters at definition time
- **Precomputed rotations** — all 8 rotation amounts used by xxh64 have dedicated functions with baked-in shift constants
- **Strict accumulator pattern** — `builtins.deepSeq` at fold boundaries prevents thunk chain buildup (inspired by Haskell's `BangPatterns`)

Performance (100k hashes, startup excluded, 8-byte input): ~17µs/hash pure Nix vs ~0.9µs/hash for `builtins.hashString "sha256"` (C builtin).

### Primitives

Low-level building blocks in `pure/primitives/`, all zero-dependency (`builtins` only). Originally extracted from [bird-nix-lib](https://github.com/spikespaz/bird-nix-lib) (Unlicense), rewritten to remove all nixpkgs `lib` dependencies.

| Module | Provides |
|---|---|
| `bits` | `bitShiftLeft`, `bitShiftRight` for signed 64-bit integers |
| `wrapping` | 64-bit modular `wrapAdd`, `wrapSub`, `wrapMul`, `wrapNeg`, `rotl64` |
| `split` | `{hi, lo}` split arithmetic optimized for xxh64 (splitAdd, splitMul, rotations) |
| `bytes` | `stringToBytes`, `readLE64`/`readLE32`, byte lookup table via `builtins.fromJSON` |
| `radix` | `intToHex`, `intToHexPadded` |
| `math` | `pow`, `abs`, `mod`, `round` |
| `encoding` | `encodeBinary`, `decodeBinary` (MSB-first bit lists) |
| `lists` | `indexOf`, `sublist`, `split`, `lpad`, `rpad`, `reverse`, etc. |
| `strings` | `charAt`, `indexOfChar`, `removeChars`, `lpadString`, `rpadString` |
| `trivial` | Boolean ops (`xor`, `nand`, etc.), `imply`, `applyAutoArgs` |

```nix
gen.primitives.bits.bitShiftLeft 8 1    # → 256
gen.primitives.wrapping.wrapMul a b     # → (a * b) mod 2^64
gen.primitives.bytes.stringToBytes "AB" # → [ 65 66 ]
```

## Module Tier

These primitives require `{ lib }` from nixpkgs. Accessing them without passing `lib` throws a clear error.

### `mkIdentityModule`

Injects `id_hash` (deterministic SHA-256) and `_identity.keys` into a NixOS module. Uses `builtins.hashString "sha256"` for production identity hashing. Hash is computed from primitive options (str, int, bool), prefixed by kind name.

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

See [`templates/demo/`](templates/demo/) for a self-contained example exercising search monad workflow, intensional dedup, and validation.

```bash
cd templates/demo
nix eval --override-input gen ../.. .#searchResult
nix eval --override-input gen ../.. .#dedupResult
nix eval --override-input gen ../.. .#validationPass
nix eval --override-input gen ../.. .#validationFail
```

## Testing

Tests live in `templates/ci/` using nix-unit:

```bash
nix-unit --flake ./templates/ci#tests --override-input gen .
```

## Architecture

```
gen/
  default.nix              — entry point ({ lib ? null }), two-tier dispatch
  flake.nix                — flake outputs (__functor + lib)
  pure/
    default.nix            — exports search, intensional, xxh64, primitives
    search.nix             — Palmer §3 Search monad (8 public primitives)
    intensional.nix        — mkIntensional, intensionalEq
    identity.nix           — mkIdentity (standalone hash)
    xxh64.nix              — pure-Nix xxh64 (reference implementation)
    primitives/
      default.nix          — re-exports all primitive modules
      bits.nix             — bitShiftLeft, bitShiftRight (signed 64-bit)
      wrapping.nix         — 64-bit modular arithmetic
      split.nix            — {hi,lo} split arithmetic (xxh64-optimized)
      bytes.nix            — stringToBytes, readLE64/32, byte table
      radix.nix            — intToHex, intToHexPadded
      math.nix             — pow, abs, mod, round
      encoding.nix         — binary encode/decode
      lists.nix            — indexOf, sublist, split, lpad, rpad, reverse
      strings.nix          — charAt, indexOfChar, removeChars, pad
      trivial.nix          — boolean ops, imply, applyAutoArgs
  module/
    default.nix            — exports identity + validation + strict + ref
    identity.nix           — mkIdentityModule (id_hash via SHA-256)
    validate.nix           — mkValidator, runValidators, formatErrors, defaultOnError
    strict.nix             — mkStrictModule (strict freeform rejection)
    ref-type.nix           — mkRefType (cross-registry references)
  bench/
    default.nix            — xxh64 vs SHA256 benchmark expressions
    run.sh                 — benchmark runner (wall-clock timing)
  templates/
    ci/                    — nix-unit test suite (228 tests)
    demo/                  — self-contained demo (search + dedup + validation)
```

The pure tier has zero dependencies — consumers needing only search or intensional functions don't pull in nixpkgs. The module tier takes `{ lib }` for NixOS module system primitives. Accessing module-tier functions without `lib` throws with a clear message rather than silently being absent.

## License

MIT
