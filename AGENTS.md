# gen-algebra — agent capability sheet

## Scope

Pure-algebra root of the gen ecosystem: a Palmer §3 search monad, Leijen/Bracha record algebra with scoped labels and layer folding, Either combinators, intensional-function constructors, and standalone identity hashing — `builtins` only, zero flake inputs.

## Not this library's job

Quoted text is the owner's own `flake.nix` `description` field, verbatim.

| Responsibility | Owner |
|---|---|
| General-purpose list/string/attr utilities — gen-algebra vendors its own private `drop` rather than import one (`lib/search.nix:37-43`) | `gen-prelude` — "gen-prelude: vendored, nixpkgs-lib-free pure utilities for the gen ecosystem" |
| Type checking / structural verification | `gen-types` — "gen-types: pure, nixpkgs-lib-free structural type checker for the gen ecosystem" |
| Module merge, `evalModules`, options — `ci/tests/purity.nix` fails the suite on `evalModules` / `mkOption` / `lib.` / `nixpkgs` anywhere in `lib/**.nix`, root `flake.nix`, `default.nix` | `gen-merge` — "gen-merge — pure-Nix byte-mode module MERGE engine (evalModuleTree) for the pure-gen module system" |
| Typed registries, kinds/instances, and **all** identity minting — `hashIdentity` is the substrate's single minting authority, and gen-algebra's standalone `name`+`fields` hasher retired into it | `gen-schema` — "gen-schema: typed record registry with extension points for the pure-gen module system" |
| Stratified settings resolution, refs-as-data, graduated injection — the in-ecosystem consumer of `record.foldLayersTraced` (`gen-settings/lib/resolve.nix:33`) | `gen-settings` — "gen-settings — stratified settings resolution as a pure layered fold, with refs-as-data, structured provenance, and the graduated injection construct" |
| Aspect traits / classification / composition types | `gen-aspects` — "gen-aspects: aspect-oriented composition types (pure-gen, re-hosted on gen-merge)" |
| Graph traversal, condensation, query combinators | `gen-graph` — "gen-graph: accessor-based graph query combinators" |
| Scope-graph construction and demand-driven attribute evaluation | `gen-scope` — "gen-scope: demand-driven attribute grammar evaluator over algebraic scope graphs" |
| Scheduled attribute convergence — `search.converge` is an untyped index fixpoint with no attribute schedule | `gen-resolve` — "gen-resolve — demand-driven higher-order RAG evaluator over algebraic scope graphs (Knuth 1968 attribute schedule + Vogt 1989 HOAG)" |
| Matching predicates against graph positions — gen-select re-implements the one-line `intensionalEq` inline instead of importing it (`gen-select/lib/constructors.nix:126-134`; `gen-select/flake.nix:5` records "no gen-algebra") | `gen-select` — "gen-select: selector algebra for attributed graph positions" |
| Rule dispatch, ordering, conflict resolution — `gen-dispatch/flake.nix:5` records gen-algebra as a removed (dead) input | `gen-dispatch` — "gen-dispatch: relational rule dispatch over ordered groups (the dispatch STEP)" |
| Fold/scan/route as *dataflow over channels* (distinct from `record.foldLayers`, which folds plain attrsets) | `gen-pipe` — "gen-pipe — scoped channels + dataflow algebra (map/filter/fold/scan/route/join/tee) with B5 determinism, provenance, dedup, and class-aware contributions" |
| Change propagation, AFFECTED sets, incremental rebuild | `gen-rebuild` — "gen-rebuild: pure-Nix incremental rebuilder core (Mokhov rebuilder dimension)" |
| The nixpkgs boundary — building anything, injecting resolved values | `gen-flake` — "gen-flake — the pure composition boundary of the pure-gen module ecosystem" |

Declared flake inputs on gen-algebra across the sibling set: `gen-link`, `gen-resolve`, `gen-schema`, `gen-settings`.

## Exports

Entry: `inputs.gen-algebra.lib` (flake, `flake.nix:9`). Root `default.nix` is `import ./lib` (`default.nix:4`) — the same bare value, not a function, so it takes no dependency argument.

Six top-level names: three namespaces (`search`, `record`, `either`) and three bare functions.

**Search monad** — `lib/search.nix`, reached as `search.*`

| Export | Signature |
|---|---|
| `empty` | `state` (a value: `{ index = {}; results = []; continuations = []; }`) |
| `insert` | `key -> value -> state -> state` (appends to the key's list) |
| `lookup` | `key -> state -> [value]` (`[]` when absent) |
| `has` | `key -> state -> bool` |
| `emit` | `[item] -> state -> state` (appends to `results`) |
| `foldl` | `(acc -> x -> acc) -> acc -> [x] -> acc` — literally `builtins.foldl'` (`lib/search.nix:25`) |
| `on` | `key -> (value -> state -> state) -> state -> state` (registers a continuation) |
| `converge` | `state -> state` (fixpoint; hard cap 1000 iterations) |

**Record algebra, core** (Leijen §2) — `lib/rec.nix`, reached as `record.*`. Representation is `{ __entries = { label = [stack]; }; __order = [label]; }`.

| Export | Signature |
|---|---|
| `empty` | `record` (a value) |
| `extend` | `record -> label -> value -> record` (pushes onto the label's stack) |
| `select` | `record -> label -> value` (head; throws if absent) |
| `restrict` | `record -> label -> record` (pops head; no-op if absent) |
| `has` | `record -> label -> bool` |
| `depth` | `record -> label -> int` (0 if absent) |

**Record, conversion and display**

| Export | Signature |
|---|---|
| `emit` | `record -> attrset` (heads only) |
| `emitAll` | `record -> [label] -> attrset` (full stacks for listed labels, heads for the rest) |
| `fromAttrs` | `attrset -> record` (single-element stacks) |
| `labels` | `record -> [label]` |
| `show` | `record -> string` (full stacks, via `toJSON`) |
| `showCompact` | `record -> string` (heads, via `toJSON`) |

**Record, derived**

| Export | Signature |
|---|---|
| `update` | `record -> label -> value -> record` (replaces head; throws if absent) |
| `upsert` | `record -> label -> value -> record` (insert-or-replace) |
| `rename` | `record -> old -> new -> record` (throws if `old` absent) |

**Record, composition** (Bracha §2-4)

| Export | Signature |
|---|---|
| `combine` | `record -> record -> record` (left-biased ⊕; left's stacks above right's) |
| `mixin` | `(record -> record) -> record -> record` (Smalltalk direction: `combine (delta parent) parent`) |
| `mixinBeta` | `(record -> record) -> record -> record` (Beta leaf form, `inner = empty`) |
| `compose` | `(record -> record) -> (record -> record) -> record -> record` (⋆) |

**Record, row compatibility**

| Export | Signature |
|---|---|
| `satisfies` | `record -> [label] -> bool` |
| `assertSatisfies` | `record -> [label] -> record` (throws listing missing labels) |

**Record, layer folding** — operates on **plain attrsets**, not `record` values

| Export | Signature |
|---|---|
| `foldLayers` | `{ strategies ? {}; defaults ? {}; layers ? []; } -> attrset` |
| `foldLayersTraced` | `{ strategies ? {}; defaults ? {}; layers ? []; layerNames ? []; defaultLabel ? "default"; } -> { value; provenance; }` |
| `flattenAttrs` | `{ strategies ? {}; prefix ? ""; } -> attrset -> attrset` (two arguments) |
| `unflattenAttrs` | `attrset -> attrset` |
| `foldNestedLayers` | `{ strategies ? {}; defaults ? {}; layers ? []; } -> attrset` (flatten → `foldLayers` → unflatten) |

Strategy vocabulary is **not uniform**: `foldLayers` and `foldNestedLayers` accept `"replace"` (default) / `"append"` / `"recursive"` (`lib/rec.nix:200-207`); `foldLayersTraced` accepts those plus `"semilattice-set"` (`lib/rec.nix:254-265`). Layers are least-specific first.

**Either** — `lib/either.nix`, reached as `either.*`. Values are `{ right = v; }` | `{ left = e; }`.

| Export | Signature |
|---|---|
| `right` / `left` | `value -> Either` |
| `pipe` | `[(value -> Either)] -> value -> Either` (short-circuits on first `left`) |
| `collectErrors` | `[(value -> Either)] -> value -> Either` (no short-circuit; `left` payload is a **list**) |
| `mapR` | `(a -> b) -> Either -> Either` |
| `chain` | `(a -> Either) -> Either -> Either` |

No `isRight` / `fromRight` / `bimap` — consumers test `? right` / `? left` directly.

**Intensional functions and identity** — top level

| Export | Signature |
|---|---|
| `mkIntensional` | `name -> closure -> fn -> { name; closure; fn; __functor; }` (callable) |
| `intensionalEq` | `intensional -> intensional -> bool` (compares `.name` only) |

## Entry points by task

| Task | Reach for |
|---|---|
| Accumulate keyed facts and run them to a fixpoint | `search.insert` / `search.on` / `search.converge` |
| Read accumulated facts | `search.lookup` (values by key) / `.results` (emitted items) |
| Make a continuation deduplicable | `mkIntensional "<name>" {} fn` — a bare lambda is never deduped |
| Compare two functions for identity | `intensionalEq` — name-only; fold any distinguishing data into the name |
| Build a record whose labels can shadow | `record.fromAttrs` then `record.extend` |
| Read the current binding / the shadowed one | `record.select r l` / `record.select (record.restrict r l) l` |
| Ship a record to ordinary Nix | `record.emit` (heads) or `record.emitAll r [ labels ]` (stacks preserved) |
| Compose two records or two mixins | `record.combine` / `record.mixin` / `record.mixinBeta` / `record.compose` |
| Assert a record carries required labels | `record.satisfies` (bool) / `record.assertSatisfies` (throws) |
| Merge priority tiers of plain attrsets | `record.foldLayers { strategies; defaults; layers; }` |
| Same, but needing per-field provenance or set-union merge | `record.foldLayersTraced` (adds `layerNames`, `"semilattice-set"`) |
| Merge nested attrsets by tier | `record.foldNestedLayers` (or `flattenAttrs` / `unflattenAttrs` directly) |
| Short-circuit a validation chain | `either.pipe` |
| Report every validation failure at once | `either.collectErrors` |

## Measured traps

Each row verified in this run by evaluating against `a = import ./lib` from the repo root (`r = a.record`, `s = a.search`, `e = a.either`; `base = r.fromAttrs { level = "info"; }`, `env = r.extend base "level" "warn"`). Errors marked *(stderr)* were captured from the evaluator's message because `builtins.tryEval` does not catch that error class.

| Trap | Evidence |
|---|---|
| `"semilattice-set"` works in `foldLayersTraced` but **throws** in `foldLayers` and `foldNestedLayers` | `lib/rec.nix:200-207` vs `254-265`; traced ⇒ `{"t":["x","y","z"]}`, both others ⇒ `error: rec.foldLayers: unknown strategy 'semilattice-set' for field 't'` *(stderr)*. The byte-identity guard `test-value-identity-replace` / `-append` / `-recursive` (`ci/tests/rec-fold-layers-traced.nix`) covers the three shared strategies only; `grep -c semilattice` ⇒ 15 in `rec-fold-layers-traced.nix`, 0 in `rec-fold-layers.nix`, 0 in `rec-nested-layers.nix` |
| An unknown strategy is **silent** until some layer contributes that field — the no-contribution branch never consults `strategies` | `lib/rec.nix:198-199`; `foldLayers { strategies.q = "BOGUS"; defaults.q = 1; layers = []; }` ⇒ `{"q":1}`, same call with `layers = [ { q = 1; } ]` ⇒ throws. Test: `test-unknown-strategy-throws` (`ci/tests/rec-fold-layers-traced.nix`) exercises the contributed branch only |
| `foldLayersTraced` asserts `layerNames` is 1:1 with `layers` — omitting it is a hard failure, not a default | `lib/rec.nix:231`; `foldLayersTraced { layers = [ { a = 1; } ]; }` ⇒ `error: an integer with value '0' is not equal to an integer with value '1'`. Test: `test-length-mismatch-throws` |
| A field named only in `strategies` never reaches the output — `allKeys` is drawn from `defaults` + `layers` | `lib/rec.nix:186-189`; `foldLayers { strategies.ghost = "append"; layers = [ { real = 1; } ]; }` ⇒ `{"real":1}` |
| The layer-folding family takes **plain attrsets**; a `record` passed as a layer leaks its internals as ordinary fields | `lib/rec.nix:179-214` (no `__entries` handling); `builtins.attrNames (foldLayers { layers = [ (r.fromAttrs { a = 1; }) ]; })` ⇒ `["__entries","__order"]` |
| `intensionalEq` is **name-only**: equal names compare equal even when closures *and* function bodies differ | `lib/intensional.nix:10`; `f1 = mkIntensional "same" {} (x: x)`, `f2 = mkIntensional "same" { different = true; } (y: y*2)` ⇒ `intensionalEq f1 f2` `true`, while `f1 5` ⇒ `5` and `f2 5` ⇒ `10`. Tests: `test-intensionalEq-same-key` / `-different-key` (`ci/tests/intensional.nix`) |
| `intensionalEq` is unguarded — a bare lambda throws rather than returning `false` | `lib/intensional.nix:10`; `intensionalEq (x: x) (y: y)` ⇒ `error: expected a set but found a function` *(stderr)*. gen-select's inlined copy wraps the same one-liner in an `isIntensional` check first (`gen-select/lib/constructors.nix:126-134`, cross-repo) |
| `converge` dedups intensional continuations by `"${key}:${fn.name}"` and the **first registration wins** — a later same-name continuation is dropped body and all | `lib/search.nix:48-67`; two continuations named `"g"` on key `"k"` with different bodies ⇒ `["first:v"]`, and `["B:v"]` when registration order is swapped. Test: `test-intensional-dedup` (`ci/tests/search-converge.nix`) |
| Bare lambdas are never deduped: `keyOf` demands `? name && ? closure`, and `?` on a lambda is `false` | `lib/search.nix:51`; `(x: x) ? name` ⇒ `false`; two bare continuations on one key ⇒ `["bare2:v","bare1:v"]` (both fired). Test: `test-non-intensional-duplicates-fire-independently` |
| `converge` is incremental across calls — continuations carry a `processed` counter, so re-converging fires only on values inserted since | `lib/search.nix:83-91`; after one converge `continuations` ⇒ `[{"key":"k","processed":1}]`; inserting a second value and re-converging ⇒ `["saw:a","saw:b"]`, not a replay |
| A self-feeding continuation hits a hard cap, not a hang | `lib/search.nix:116`; ⇒ `error: search: converge exceeded 1000 iterations — likely a non-terminating continuation` *(stderr)*. Test: `test-bounded-self-insert` covers the terminating case |
| `either.pipe` tests `? left` **first**; `mapR` / `chain` test `? right` first — a value carrying both halts `pipe` but takes the right branch elsewhere | `lib/either.nix:12` vs `25,28`; `pipe [ (x: { right = x; left = "e"; }) … ] 1` ⇒ `{"left":"e","right":1}` (chain stopped), `mapR (x: x) { right = 1; left = 2; }` ⇒ `{"right":1}` (left dropped) |
| `pipe` and `collectErrors` disagree on the `left` payload: raw value vs. always a list, even for a single error | `lib/either.nix:12,22`; ⇒ `{"left":"boom"}` vs `{"left":["only"]}`. Tests: `test-pipe-short-circuits`, `test-collectErrors-single-failure` |
| `pipe` unwraps `acc.right` before each step, so a step returning a bare value fails at the **next** step, not the offending one | `lib/either.nix:12`; `pipe [ (x: x + 1) (x: e.right x) ] 1` ⇒ `error: expected a set but found an integer: 2` *(stderr)* |
| `collectErrors` evaluates every function — no short-circuit, so a later throwing function throws even after an earlier `left` | `lib/either.nix:19`; second function `builtins.throw` ⇒ threw |
| `record.restrict` on an absent label is a silent no-op, but `select` / `update` / `rename` on absent throw | `lib/rec.nix:31-32, 26-27, 75-76, 89-91`; `restrict base "nope" == base` ⇒ `true`; `error: rec: no field 'nope'` and `error: rec: no field 'nope' to update` *(stderr)*. Tests: `test-restrict-noop-on-absent`, `test-select-throws-on-absent`, `test-update-throws-on-absent` |
| `record.emit` silently discards shadowed stack values; only `emitAll` with the label listed preserves them | `lib/rec.nix:54,56-61`; on a two-deep `level` stack: `emit env` ⇒ `{"level":"warn"}`, `emitAll env [ "level" ]` ⇒ `{"level":["warn","info"]}`, `depth env "level"` ⇒ `2`. Tests: `test-emit-takes-head`, `test-emitAll-full-stacks` |
| `record.labels` is *not* insertion order in general: `fromAttrs` seeds `__order` from `builtins.attrNames` (lexicographic), and later `extend`s append | `lib/rec.nix:63-71,93`; `labels (fromAttrs { zebra = 1; apple = 2; middle = 3; })` ⇒ `["apple","middle","zebra"]`; extending that with `"aaa"` ⇒ `["apple","zebra","aaa"]`. `combine` keeps left's order then right-only labels: ⇒ `["z","a"]` |
| `combine` retains both stacks rather than discarding the right — the shadowed value stays reachable through `restrict` | `lib/rec.nix:122,129`; `combine (fromAttrs { k = "L"; }) (fromAttrs { k = "R"; })` ⇒ stack `["L","R"]`, `select` ⇒ `"L"`, `select (restrict c "k") "k"` ⇒ `"R"`. Tests: `test-combine-stacks`, `test-combine-left-order-first` |
| `show` / `showCompact` route values through `builtins.toJSON` — any function-valued field throws, and the failure escapes `tryEval` rather than being catchable | `lib/rec.nix:99,106`; both ⇒ `error: cannot convert a function to JSON` *(stderr)* |
| `search.emit` and `record.emit` share a name and are unrelated operations | `lib/search.nix:20-23` appends to `results` (⇒ `["x"]`); `lib/rec.nix:54` converts a record to a plain attrset (⇒ `{"x":1}`) |
| `flattenAttrs` treats `{}` as a leaf, so an empty attrset survives as a value rather than vanishing | `lib/rec.nix:323`; `flattenAttrs {} { a = {}; b = { c = 1; }; }` ⇒ `{"a":{},"b.c":1}`. Test: `test-flatten-empty` |
| `unflattenAttrs` splits on every literal `.`, so `foldNestedLayers` silently re-nests a key that already contained one | `lib/rec.nix:352`; `foldNestedLayers { layers = [ { "a.b" = 1; } ]; }` ⇒ `{"a":{"b":1}}` |
| `mkIntensional` takes `closure` second and `fn` third; `flattenAttrs` takes its config and target as two arguments while the fold family takes one attrset | `lib/intensional.nix:4`, `lib/rec.nix:307-312`; `(mkIntensional "n" { tag = 1; } (x: x)).closure` ⇒ `{"tag":1}`; `flattenAttrs { prefix = "p"; } { a = 1; }` ⇒ `{"p.a":1}`. Tests: `test-mkIntensional-closure-preserved`, `test-flatten-with-prefix` |

## Theory

`README.md:499-507` states its claims as a table with a **Relationship** column; the three entries and their labels are reproduced below, plus one citation made in the body but absent from that table.

**Implements structure / informed by** (README's own compound label)

- **Palmer et al. (2024), *Intensional Functions*** — the search monad with name-keyed continuation dedup (§3) in `lib/search.nix`, and the three eliminators `__functor` / `name` / `closure` (§2.2-2.3) in `lib/intensional.nix`. README records the equality and dedup as **name-only**, an explicit over-approximation of Palmer's name+closure conservative equality (§2.3 Fig 5) and *not* the Theorem 1 result, on the grounds that gen's `closure` is programmer-declared rather than compiler-extracted (`README.md:214`).

**Implements**

- **Leijen (2005), *Extensible Records with Scoped Labels*** — extension/selection/restriction (§2), scoped labels via shadow stacks (§2.1-3.2), row compatibility (§3.1), in `lib/rec.nix`.
- **Bracha & Cook (1990), *Mixin-Based Inheritance*** — left-biased combination (§2.1 ⊕), Smalltalk-direction mixin (§2.1), Beta-direction mixin (§2.2), associative composition ⋆ (§4), in `lib/rec.nix:113-162`. `mixinBeta` is annotated in-code as the leaf form with `inner = ∅`, the general form being `compose` (`lib/rec.nix:145-154`).

**Cited in the body, not in the Foundations table**

- **Datafun (ICFP 2016)** and **Flix (PLDI 2016)** — `README.md:329` grounds the `"semilattice-set"` strategy as the join of a set-union join-semilattice (ACI: associative, commutative, idempotent), standing in for those systems' lattice-valued merge. That strategy is `foldLayersTraced`-only; see traps.

**Checked invariant**: zero dependencies — `builtins` only, no nixpkgs `lib`, no module system — enforced by `ci/tests/purity.nix` (`test-library-source-is-nixpkgs-lib-free`) over `lib/**.nix` recursively plus root `flake.nix` and `default.nix`, scanning comment-stripped source for `nixpkgs`, `lib.`, `{ lib }`, `{ lib,`, `evalModules`, `mkOption`.

## Drift check

```sh
nix eval --json .#lib --apply 'l: { top = builtins.attrNames l; } // builtins.listToAttrs (map (n: { name = n; value = builtins.attrNames l.${n}; }) (builtins.filter (n: builtins.isAttrs l.${n}) (builtins.attrNames l)))'
```

The namespace set is discovered by `isAttrs` rather than hardcoded, so a new namespace appears without editing the command.

Current output (verbatim):

```json
{"either":["chain","collectErrors","left","mapR","pipe","right"],"record":["assertSatisfies","combine","compose","depth","emit","emitAll","empty","extend","flattenAttrs","foldLayers","foldLayersTraced","foldNestedLayers","fromAttrs","has","labels","mixin","mixinBeta","rename","restrict","satisfies","select","show","showCompact","unflattenAttrs","update","upsert"],"search":["converge","emit","empty","foldl","has","insert","lookup","on"],"top":["either","intensionalEq","mkIntensional","record","search"]}
```

The command observes export *names* only; signatures, strategy vocabularies, trap rows and `file:line` refs rot without changing it.

**Checks.** Test-runner invocation (from the repo root; CI runs the same command with `working-directory: ci`, `.github/workflows/ci.yml:11-18`):

```sh
nix flake check ./ci
```
