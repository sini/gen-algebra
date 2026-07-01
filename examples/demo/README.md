# gen-algebra demo

Standalone flake exercising the pure `gen-algebra.lib` primitives: the search
monad, intensional continuation dedup, the scoped record algebra, and the
`either` combinators.

`gen-algebra` exposes a single `.lib` value (the old callable
`gen-algebra { inherit lib; }` form is obsolete):

```nix
inputs.gen-algebra.url = "github:sini/gen-algebra";
# ...
g = inputs.gen-algebra.lib;
```

## What it shows

- **Search monad** (`searchResult`) — `search.insert` / `search.on` /
  `search.emit` / `search.converge`: register continuations keyed by fact,
  run to a fixed point, read `.results`.
- **Intensional dedup** (`dedupResult`) — two `mkIntensional` continuations
  with the same key collapse to one firing.
- **Record algebra** (`scopedLabels`, `recordComposition`, `rowCompatibility`)
  — scoped/stacked labels (Leijen 2005), left-biased `combine` and Smalltalk
  `mixin` (Bracha 1990), and row compatibility via `satisfies`.
- **Either** (`eitherDemo`) — short-circuiting `pipe` vs error-accumulating
  `collectErrors`, plus `mapR` / `chain`.

## Run it

Each demo is a flake output attribute; evaluate any of them:

```sh
nix eval .#searchResult --json
nix eval .#dedupResult --json
nix eval .#scopedLabels --json
nix eval .#recordComposition --json
nix eval .#rowCompatibility --json
nix eval .#eitherDemo --json
```

The expected value for each expression is written inline as a `# →` comment
next to it in `flake.nix`.
