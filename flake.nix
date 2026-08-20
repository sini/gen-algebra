{
  description = "gen-algebra: pure Nix algebra — search monad, records, intensional functions, either";

  # ★ ZERO INPUTS, AS A CONTRACT AND NOT AN ACCIDENT — and the contract's SCOPE is stated here
  # because it was previously written nowhere and both readings were manufacturable.
  #
  # What it binds: THIS flake and `./lib`. What it protects: a CONSUMER's closure — a consumer
  # resolves `lib` and gains no transitive dependency, not even nixpkgs.
  #
  # What it does NOT bind: `./ci`, which is its own flake with its own lock that no consumer ever
  # resolves. The suite may take whatever it needs to test this library honestly, and it takes the
  # real `gen-identity` mint for exactly that reason. Owner-ruled 2026-08-20 (den-hoag-soa1),
  # verbatim: "ci/ has its own flake."
  #
  # The entry is a bare value.
  outputs =
    { ... }:
    {
      lib = import ./lib;
    };
}
