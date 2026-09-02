# gen-algebra — agent capability sheet

## Scope

Pure-algebra root of the gen ecosystem: a Palmer §3 search monad, Leijen/Bracha record algebra with scoped labels and layer folding, Either combinators, and intensional-function constructors — `builtins` only, zero flake inputs. It mints no identity itself: `mkIntensional` takes the mint INJECTED, because the one minting authority (ADR-0016 ruling 5) is `gen-identity`, a dependency-free leaf downstream of nothing this library could import without a cycle.

## Not this library's job

Quoted text is the owner's own `flake.nix` `description` field, verbatim.

| Responsibility | Owner |
|---|---|
| General-purpose list/string/attr utilities — gen-algebra vendors its own private `drop` rather than import one (`lib/search.nix:37-43`) | `gen-prelude` — "gen-prelude: vendored, nixpkgs-lib-free pure utilities for the gen ecosystem" |
| Type checking / structural verification | `gen-types` — "gen-types: pure, nixpkgs-lib-free structural type checker for the gen ecosystem" |
| Module merge, `evalModules`, options — `ci/tests/purity.nix` fails the suite on `evalModules` / `mkOption` / `lib.` / `nixpkgs` anywhere in `lib/**.nix`, root `flake.nix`, `default.nix` | `gen-merge` — "gen-merge — pure-Nix byte-mode module MERGE engine (evalModuleTree) for the pure-gen module system" |
| Typed registries, kinds/instances, and identity-key REFLECTION (`id_hash` stamping) | `gen-schema` — "gen-schema: typed record registry with extension points for the pure-gen module system" |
| Identity MINTING — `hashIdentity`, the substrate's one authority (ADR-0016 ruling 5); gen-algebra's standalone `name`+`fields` hasher retired into it, and `mkIntensional` takes it INJECTED | `gen-identity` — "gen-identity: the substrate's one identity mint" |
| Stratified settings resolution, refs-as-data, graduated injection — the in-ecosystem consumer of `record.foldLayersTraced` (`gen-settings/lib/resolve.nix:33`) | `gen-settings` — "gen-settings — stratified settings resolution as a pure layered fold, with refs-as-data, structured provenance, and the graduated injection construct" |
| Aspect traits / classification / composition types | `gen-aspects` — "gen-aspects: aspect-oriented composition types (pure-gen, re-hosted on gen-merge)" |
| Graph traversal, condensation, query combinators | `gen-graph` — "gen-graph: accessor-based graph query combinators" |
| Scope-graph construction and demand-driven attribute evaluation | `gen-scope` — "gen-scope: demand-driven attribute grammar evaluator over algebraic scope graphs" |
| Scheduled attribute convergence — `search.converge` is an untyped index fixpoint with no attribute schedule | `gen-resolve` — "gen-resolve — demand-driven higher-order RAG evaluator over algebraic scope graphs (Knuth 1968 attribute schedule + Vogt 1989 HOAG)" |
| Matching predicates against graph positions — gen-select now IMPORTS gen-algebra's conservative-equality dispatch (`algebra.conservativeEq`, called from `gen-select/lib/constructors.nix`'s `selectorEq`) rather than vendoring a copy; `gen-select/flake.nix` declares gen-algebra as its one dependency (`gen-algebra.url = "github:sini/gen-algebra"`). This replaces an earlier claim that gen-select carried its own inline dispatch with private `identityOf`/`conservativeEq` bindings and declared "no gen-algebra" — true only before gen-select's own vendored-discipline retirement (`bdd5316`) | `gen-select` — "gen-select: selector algebra for attributed graph positions" |
| Rule dispatch, ordering, conflict resolution — `gen-dispatch/flake.nix:5` records gen-algebra as a removed (dead) input | `gen-dispatch` — "gen-dispatch: relational rule dispatch over ordered groups (the dispatch STEP)" |
| Fold/scan/route as *dataflow over channels* (distinct from `record.foldLayers`, which folds plain attrsets) | **`gen-view`, which inherited it — `gen-pipe` RETIRED as a library rather than moving as one.** ADR-0010 §3 retires gen-pipe into the movement vocabulary, and the ruling gained a fourth destination on 2026-08-20: gen-view, the substrate's derived-view constructor. Twelve of the seventeen exports — `channel` `map` `filter` `fold` `scan` `over` `route` `tee` `compose` `run` `provenanceOf` `traceOf` — name gen-view constructs; `sel` retires into `gen-select`, which consumers bind directly. The gen-pipe repository orphans as reference under ADR-0031 §3's F3 pattern, off the `gen/lib/mkGenLibs.nix` roster and not a `gen` hub input. The distinction this row draws still holds and is why it is kept: `record.foldLayers` folds plain attrsets and is this library's own |
| Change propagation, AFFECTED sets, incremental rebuild | `gen-memo` — "gen-memo — the incremental plane: a decision layer over the evaluator that never evaluates, only decides reuse" |
| The nixpkgs boundary — building anything, injecting resolved values | `gen-flake` — "gen-flake — the pure composition boundary of the pure-gen module ecosystem" |

Declared flake inputs on gen-algebra across the sibling set: `gen-link`, `gen-schema`, `gen-select`, `gen-settings`.

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
| `foldLayersTraced` | `{ strategies ? {}; defaults ? {}; layers ? []; layerNames ? []; defaultLabel ? "default"; entryTransform ? null; } -> { value; provenance; }` |
| `flattenAttrs` | `{ strategies ? {}; prefix ? ""; } -> attrset -> attrset` (two arguments) |
| `unflattenAttrs` | `attrset -> attrset` |
| `foldNestedLayers` | `{ strategies ? {}; defaults ? {}; layers ? []; } -> attrset` (flatten → `foldLayers` → unflatten) |

Strategy vocabulary is **not uniform**: `foldLayers` and `foldNestedLayers` accept `"replace"` (default) / `"append"` / `"recursive"` (`lib/rec.nix`, `foldLayers`'s `resolveField`); `foldLayersTraced` accepts those plus `"semilattice-set"` (its own `resolve`). Layers are least-specific first.

`entryTransform` is `field -> entry -> entry'`, applied to every entry of a field's provenance chain including the default entry. It is **not** a post-hoc `map`: application is per entry and demand-driven, so forcing the chain's spine, one entry's own record, or a sibling entry never applies it elsewhere, and the `value` path never applies it at all. A transform lazy in its derived part therefore leaves a diverging entry harmless to the rest of the trace. Omitted, the chain is emitted untransformed.

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
| `mkIntensional` | `hashIdentity -> registry -> ctor -> args -> { ctor; args; name; closure; fn; __mint; __functor; }` (callable). `registry` is `{ revision; members; }`; the mint is INJECTED because `hashIdentity` is downstream |
| `conservativeEq` | `intensional -> intensional -> bool` (dispatches on the `__mint` regime; digests where minted, whole-value `==` minus `__id` otherwise) |
| `identityOf` / `regimeTagOf` / `isExact` / `comparisonSubject` | the identity-regime readers — a consumer that DECIDES dispatches on the tag and never reads `__mint.minted` raw |

## The zero-inputs contract, and what it binds

★ **It binds `flake.nix` and `lib/`, and it does NOT bind `ci/`.** Written down because it was
previously stated in no flake comment, no AGENTS row and no ADR, so both readings could be
manufactured from the tree.

| | binds | why |
|---|---|---|
| root `flake.nix` + `lib/` | **YES** | what the contract protects is a CONSUMER's closure, and a consumer resolves `lib` — it gains no transitive dependency, not even nixpkgs |
| `ci/` | **NO** | `ci/` is its own flake with its own lock, and no consumer ever resolves it. The suite may take whatever it needs to test this library honestly |

Owner-ruled 2026-08-20 (`den-hoag-soa1`), verbatim: *"ci/ has its own flake."*

★ **The consequence is live**: the suite takes the real `gen-identity` mint rather than a
stand-in. A stand-in could carry the CONSTRUCTOR's arms and nothing else, which left the
composition of encoder and constructor untested by construction — the one thing no suite on
either side could reach on its own.

## Entry points by task

| Task | Reach for |
|---|---|
| Accumulate keyed facts and run them to a fixpoint | `search.insert` / `search.on` / `search.converge` |
| Read accumulated facts | `search.lookup` (values by key) / `.results` (emitted items) |
| Make a continuation deduplicable | `mkIntensional hashIdentity registry "<ctor>" args` — a bare lambda is never deduped |
| Compare two functions for identity | `conservativeEq` — regime-dispatched; nothing to fold into a name, the coordinate is `(registry, ctor, args)` |
| Build a record whose labels can shadow | `record.fromAttrs` then `record.extend` |
| Read the current binding / the shadowed one | `record.select r l` / `record.select (record.restrict r l) l` |
| Ship a record to ordinary Nix | `record.emit` (heads) or `record.emitAll r [ labels ]` (stacks preserved) |
| Compose two records or two mixins | `record.combine` / `record.mixin` / `record.mixinBeta` / `record.compose` |
| Assert a record carries required labels | `record.satisfies` (bool) / `record.assertSatisfies` (throws) |
| Merge priority tiers of plain attrsets | `record.foldLayers { strategies; defaults; layers; }` |
| Same, but needing per-field provenance or set-union merge | `record.foldLayersTraced` (adds `layerNames`, `"semilattice-set"`) |
| Emit a *derived* reading of each provenance entry, without a diverging one poisoning the chain | `record.foldLayersTraced`'s `entryTransform` — never a `map` over the finished provenance |
| Merge nested attrsets by tier | `record.foldNestedLayers` (or `flattenAttrs` / `unflattenAttrs` directly) |
| Short-circuit a validation chain | `either.pipe` |
| Report every validation failure at once | `either.collectErrors` |

## Measured traps

Each row verified in this run by evaluating against `a = import ./lib` from the repo root (`r = a.record`, `s = a.search`, `e = a.either`; `base = r.fromAttrs { level = "info"; }`, `env = r.extend base "level" "warn"`). Errors marked *(stderr)* were captured from the evaluator's message because `builtins.tryEval` does not catch that error class.

| Trap | Evidence |
|---|---|
| `"semilattice-set"` works in `foldLayersTraced` but **throws** in `foldLayers` and `foldNestedLayers` — so the two folds are siblings over a shared domain, never one primitive | `lib/rec.nix`, `foldLayers`'s `resolveField` vs `foldLayersTraced`'s `resolve`; traced ⇒ `{"t":["x","y","z"]}`, both others ⇒ `error: rec.foldLayers: unknown strategy 'semilattice-set' for field 't'` *(stderr)*. The byte-identity guard names its domain and covers all of it — `test-value-identity-replace` / `-append` / `-recursive` / `-explicit-replace-and-default-only` (`ci/tests/rec-fold-layers-traced.nix`) — which is what licenses a consumer computing an expected from `foldLayers`, on that domain and nowhere else; `grep -c semilattice` ⇒ 15 in `rec-fold-layers-traced.nix`, 0 in `rec-fold-layers.nix`, 0 in `rec-nested-layers.nix` |
| An unknown strategy is **silent** until some layer contributes that field — the no-contribution branch never consults `strategies` | `lib/rec.nix:198-199`; `foldLayers { strategies.q = "BOGUS"; defaults.q = 1; layers = []; }` ⇒ `{"q":1}`, same call with `layers = [ { q = 1; } ]` ⇒ throws. Test: `test-unknown-strategy-throws` (`ci/tests/rec-fold-layers-traced.nix`) exercises the contributed branch only |
| `foldLayersTraced` asserts `layerNames` is 1:1 with `layers` — omitting it is a hard failure, not a default | `lib/rec.nix`, `foldLayersTraced`'s leading `assert`; `foldLayersTraced { layers = [ { a = 1; } ]; }` ⇒ `error: an integer with value '0' is not equal to an integer with value '1'`. Test: `test-length-mismatch-throws` |
| `entryTransform` is absent by **sentinel**, not by an identity default — the untransformed chain costs no per-entry application, and a supplied transform is applied to the default entry too | `lib/rec.nix`, `foldLayersTraced`'s `resolve` (`if entryTransform == null`); one fixture read both ways ⇒ with a transform, each entry's `attrNames` is `["derived","field","layer"]`; with the field dropped, the chain is `[{"layer":"default","value":"D"},{"layer":"l0","value":"w"}]`. Tests: `test-entry-transform-applied` / `-absent-is-untransformed` / `-empty` (`ci/tests/rec-fold-layers-traced.nix`) |
| A field named only in `strategies` never reaches the output — `allKeys` is drawn from `defaults` + `layers` | `lib/rec.nix:186-189`; `foldLayers { strategies.ghost = "append"; layers = [ { real = 1; } ]; }` ⇒ `{"real":1}` |
| The layer-folding family takes **plain attrsets**; a `record` passed as a layer leaks its internals as ordinary fields | `lib/rec.nix:179-214` (no `__entries` handling); `builtins.attrNames (foldLayers { layers = [ (r.fromAttrs { a = 1; }) ]; })` ⇒ `["__entries","__order"]` |
| `mkIntensional` is a FOUR-argument encoder and the first two are injected: the mint, then the registry. A three-argument call throws by name | `lib/intensional.nix`, binding `mkIntensional`; `mkIntensional h { revision = "r1"; members.addN = a: (x: x + a.n); } "addN" { n = 1; }`. An undeclared `ctor` ⇒ `intensional: unknown constructor '<ctor>'`; a registry with no `revision` ⇒ `intensional: registry declares no revision`. Tests: `test-refuses-unknown-constructor`, `test-refuses-registry-without-revision` |
| `conservativeEq` SEPARATES two values sharing a `ctor` and differing in `args` — the pair the retired name-only relation merged | `lib/intensional.nix`, binding `conservativeEq`; `a = mk "addN" { n = 1; }`, `b = mk "addN" { n = 2; }` ⇒ `conservativeEq a b` `false` while `a.name == b.name` is still `true` and `a 5` ⇒ `6`, `b 5` ⇒ `7`. Tests: `test-conservativeEq-separates-differing-args`, `test-control-equal-coordinates-merge` (`ci/tests/intensional.nix`) |
| `conservativeEq` is unguarded — a bare lambda throws rather than returning `false` | `lib/intensional.nix`, binding `conservativeEq`; `conservativeEq (x: x) (y: y)` ⇒ `error: expected a set but found a function` *(stderr)*. gen-select guards its own relation with an `isIntensional` check first (`gen-select/lib/constructors.nix`, binding `selectorEq`, cross-repo) |
| `converge` dedups intensional continuations by **identity regime**, not by name. Same-key continuations sharing one program point but **behaving differently now BOTH FIRE** — the key is a bucket and membership is decided by Nix `==` on the reified value minus `__id` | `lib/intensional.nix`, bindings `identityOf` / `comparisonSubject`, consumed by `lib/search.nix`'s `classify` / `dedupContinuations`; two continuations named `"g"` on key `"k"` with different bodies ⇒ **both fire**. RED control, the retired presence loop on the same pair ⇒ **one fires** — the later registration was dropped body and all, silently. Test: `test-intensional-dedup` (`ci/tests/search-converge.nix`) covers the merging arm (one value bound twice ⇒ one survivor) |
| Dedup precision on the non-minted arms is an **allocation artefact**, and merging is what it may lose | `lib/search.nix`, binding `dedupContinuations`; one value registered twice ⇒ **one** survivor, two separately-constructed equal-shaped values ⇒ **two**. `search.converge` merges WORK, so a finer relation costs dedup and never correctness |
| Bare lambdas are never deduped: `classify` demands `? name && ? closure`, and `?` on a lambda is `false` | `lib/search.nix`, binding `classify` (which replaced the former `keyOf` and now returns `{ key; exact; }`); `(x: x) ? name` ⇒ `false`; two bare continuations on one key ⇒ `["bare2:v","bare1:v"]` (both fired). Test: `test-non-intensional-duplicates-fire-independently` |
| The dedup key carries a REGIME TAG between the index key and the payload — `"${key}:m\|s\|u:${payload}"` — so the three arms occupy disjoint spaces | `lib/intensional.nix`, binding `regimeTagOf`, consumed by `lib/search.nix`'s `classify`; an unmigrated continuation NAMED string-equal to another's minted digest fires alongside it in **both** registration orders. RED control, the same tree with the tag removed: registering the unmigrated one first drops the minted one — an **order-sensitive** silent drop, invisible to a one-order probe. Test: `test-name-cannot-forge-a-minted-key` |
| `__id` is excluded from the compared subject, and it is the ONLY exclusion | `lib/intensional.nix`, binding `comparisonSubject`; a sealed continuation carrying `__id = throw …` still dedups — distinct pair ⇒ both fire, one value twice ⇒ one. `__id` is the accessor a consumer reads when it DEMANDS an identity, so where nothing is minted it IS the named refusal, and forcing it inside a bucket scan detonates the decision the refusal exists to permit. Test: `test-sealed-bucket-does-not-force-id` |
| Whether a key is a dedup key or a bucket label is read off `identityOf`, not off `__mint` a second time | `lib/intensional.nix`, binding `isExact` (`i: i ? minted`), consumed by `lib/search.nix`'s `classify`. One `identityOf` read per continuation feeds both the key and its exactness, so the tagged sum keeps a single reader |
| `converge` is incremental across calls — continuations carry a `processed` counter, so re-converging fires only on values inserted since | `lib/search.nix`, binding `converge`'s `step` (the `rebuilt` fold that recomputes `processed`); after one converge `continuations` ⇒ `[{"key":"k","processed":1}]`; inserting a second value and re-converging ⇒ `["saw:a","saw:b"]`, not a replay |
| A self-feeding continuation hits a hard cap, not a hang | `lib/search.nix`, binding `converge`'s `iterate`; ⇒ `error: search: converge exceeded 1000 iterations — likely a non-terminating continuation` *(stderr)*. Test: `test-bounded-self-insert` covers the terminating case |
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
| `flattenAttrs` treats `{}` as a leaf, so an empty attrset survives as a value rather than vanishing | `lib/rec.nix`, `flattenAttrs`'s `go` (the `v != { }` guard on its descend branch); `flattenAttrs {} { a = {}; b = { c = 1; }; }` ⇒ `{"a":{},"b.c":1}`. Test: `test-flatten-empty` |
| `unflattenAttrs` splits on every literal `.`, so `foldNestedLayers` silently re-nests a key that already contained one | `lib/rec.nix`, `unflattenAttrs`'s `parts` (`builtins.split "\\."`); `foldNestedLayers { layers = [ { "a.b" = 1; } ]; }` ⇒ `{"a":{"b":1}}` |
| `mkIntensional` is CURRIED four deep, so a partial application is a value worth binding; `flattenAttrs` takes its config and target as two arguments while the fold family takes one attrset | `lib/intensional.nix`, binding `mkIntensional`, `lib/rec.nix`'s `flattenAttrs` signature (`{ strategies, prefix }: attrs:`, two arguments); `(mk "mulN" { n = 2; }).closure` ⇒ `{"n":2}`; `flattenAttrs { prefix = "p"; } { a = 1; }` ⇒ `{"p.a":1}`. Tests: `test-closure-is-the-argument-value`, `test-flatten-with-prefix` |

## Theory

`README.md` § *Theoretical Foundations* states its claims as a table with a **Relationship** column; the five entries and their labels are reproduced below, plus one citation made in the body but absent from that table.

**Implements structure / informed by** (README's own compound label)

- **Palmer et al. (2024), *Intensional Functions*** — the search monad with continuation dedup (§3) in `lib/search.nix`, and the eliminators `__functor` / `name` / `closure` (§2.2-2.3) in `lib/intensional.nix`. **The constructor is an ENCODER.** Palmer discharges closure consistency by construction at an encoder and never by a check (Def 5.5-5.7), and gen's constructor is that transposed: the author supplies `(ctor, args)` and a registry builds the function, so an under-complete closure is INEXPRESSIBLE rather than undetected. The identity coordinate carries the registry instance as well as `(ctor, args)`, because Nix has no linking and §6.1's capture rule therefore excludes nothing. **Both dedup and `conservativeEq` are regime-dispatched, not name-keyed:** Fig. 5 is a conjunction over identity AND closure, and a program point is constant across a constructor's instances, so a name-only relation merged behaviourally distinct values. Keys are exact where an identity is minted and **buckets** otherwise, membership decided by Nix `==` on the reified value minus `__id`, every key carrying a regime tag so the three arms occupy disjoint spaces. **The closure-consistency hypotheses discharge CONDITIONALLY**, on a registry `revision` an author can get wrong. **Theorem 1 does not transfer**: it is a preservation theorem about 𝜆ITS reduction and gen is not 𝜆ITS (`README.md` § *`conservativeEq`*).

**Implements**

- **Lorenzen et al. (2025), *First-Class Labels: First-Order Laziness*** — the registry construction in `lib/intensional.nix` IS a lazy constructor (§1): inert first-order operands (`{ ctor; args; }`), behaviour being "the associated right-hand side of the data declaration" looked up BY CONSTRUCTOR at forcing (`fn = registry.members.<ctor> args`), and the operands readable before anything is forced — the paper's `debug-show` property. Identified at the landed construction rather than derived from the paper, and scoped to §1's construct: none of the memoization, in-place-reuse or reference-counting results are claimed. **§8 is where the two part company** — lazy constructors "have to be declared up-front in the data type definition", so Lorenzen's map is CLOSED at one declaration site, while gen's registry is an open caller-supplied value. That openness is the whole reason `revision` must enter the identity coordinate.

**Informed by**

- **Reynolds (1972), *Definitional Interpreters for Higher-Order Programming Languages*** — the constructor-plus-inert-argument SHAPE only (§6, pp. 376-377): replace a function value by a tag plus inert fields and interpret the tag. **Deliberately scoped, because three things do NOT transfer.** His record fields are READ OFF the lambda's own global variables — §6's table gives one record equation per lambda expression, keyed by its "Global Variables" column — where an author here CHOOSES what `args` holds. Elimination is a single interpretive `apply` doing CLOSED case analysis over `FUNVAL = CLOSR ∪ SC ∪ EQ1 ∪ EQ2`, where dispatch here is an attribute selection into an open map. And that union is enumerated from every lambda expression in the program, so it is a whole-program transformation with no registry to pass. Cite Lorenzen, not Reynolds, for the registry.

**Implements**

- **Leijen (2005), *Extensible Records with Scoped Labels*** — extension/selection/restriction (§2), scoped labels via shadow stacks (§2.1-3.2), row compatibility (§3.1), in `lib/rec.nix`.
- **Bracha & Cook (1990), *Mixin-Based Inheritance*** — left-biased combination (§2.1 ⊕), Smalltalk-direction mixin (§2.1), Beta-direction mixin (§2.2), associative composition ⋆ (§4), in `lib/rec.nix:113-162`. `mixinBeta` is annotated in-code as the leaf form with `inner = ∅`, the general form being `compose` (`lib/rec.nix:145-154`).

**Cited in the body, not in the Foundations table**

- **Datafun (ICFP 2016)** and **Flix (PLDI 2016)** — `README.md` § *`foldLayers`* (the "Strategy types" list, `"semilattice-set"` bullet) grounds the `"semilattice-set"` strategy as the join of a set-union join-semilattice (ACI: associative, commutative, idempotent), standing in for those systems' lattice-valued merge. That strategy is `foldLayersTraced`-only; see traps.
- **Launchbury (1993), *A Natural Semantics for Lazy Evaluation*** — `README.md` § *`entryTransform`* and `lib/rec.nix`'s `foldLayersTraced` cite §2's call-by-need as the semantics the per-entry non-interference law rests on. The law is *stated and tested*, not implemented from the paper: Nix supplies the demand-driven forcing, and `entryTransform`'s contribution is to place the refinement where each entry's own demand reaches it.

**Checked invariant**: zero dependencies — `builtins` only, no nixpkgs `lib`, no module system — enforced by `ci/tests/purity.nix` (`test-library-source-is-nixpkgs-lib-free`) over `lib/**.nix` recursively plus root `flake.nix` and `default.nix`, scanning comment-stripped source for `nixpkgs`, `lib.`, `{ lib }`, `{ lib,`, `evalModules`, `mkOption`.

## Drift check

```sh
nix eval --json .#lib --apply 'l: { top = builtins.attrNames l; } // builtins.listToAttrs (map (n: { name = n; value = builtins.attrNames l.${n}; }) (builtins.filter (n: builtins.isAttrs l.${n}) (builtins.attrNames l)))'
```

The namespace set is discovered by `isAttrs` rather than hardcoded, so a new namespace appears without editing the command.

Current output (verbatim):

```json
{"either":["chain","collectErrors","left","mapR","pipe","right"],"record":["assertSatisfies","combine","compose","depth","emit","emitAll","empty","extend","flattenAttrs","foldLayers","foldLayersTraced","foldNestedLayers","fromAttrs","has","labels","mixin","mixinBeta","rename","restrict","satisfies","select","show","showCompact","unflattenAttrs","update","upsert"],"search":["converge","emit","empty","foldl","has","insert","lookup","on"],"top":["comparisonSubject","conservativeEq","either","identityOf","isExact","mkIntensional","record","regimeTagOf","search"]}
```

The command observes export *names* only; signatures, strategy vocabularies, trap rows and `file:line` refs rot without changing it.

**Checks.** Test-runner invocation (from the repo root; CI runs the same command with `working-directory: ci`, `.github/workflows/ci.yml:11-18`):

```sh
nix flake check ./ci
```
