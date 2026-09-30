# gen-algebra demo

Standalone flake exercising the pure `gen-algebra.lib` primitives: the scoped
record algebra and the `either` combinators.

The demo binds the library from the checkout it ships in, through the standalone
entry `g = import ../.. { };`, so it evaluates against that tree and its lock
pins nothing of `gen-algebra` itself. A flake of your own consumes the single
`.lib` value instead:

```nix
inputs.gen-algebra.url = "github:sini/gen-algebra";
# ...
g = inputs.gen-algebra.lib;
```

## What it shows

- **Record algebra** (`scopedLabels`, `recordComposition`, `rowCompatibility`)
  — scoped/stacked labels (Leijen 2005), left-biased `combine` and Smalltalk
  `mixin` (Bracha 1990), and row compatibility via `satisfies`.
- **Either** (`eitherDemo`) — short-circuiting `pipe` vs error-accumulating
  `collectErrors`, plus `mapR` / `chain`.

## Run it

Each demo is a flake output attribute; evaluate any of them:

```sh
nix eval .#scopedLabels --json
nix eval .#recordComposition --json
nix eval .#rowCompatibility --json
nix eval .#eitherDemo --json
```

The expected value for each expression is written inline as a `# →` comment
next to it in `flake.nix`.
