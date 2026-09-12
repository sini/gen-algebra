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
      # `nix flake check` forces the WHNF of every top-level output and nothing deeper, so this root's
      # green quantified over the `lib` SPINE alone: a member of the published surface could throw and
      # the check still exited 0 (measured — den-hoag-z1ta6). Hanging the force on that spine is what
      # makes the green mean "the surface evaluates", and a library needs no new output name for it.
      # The depth is each member's WHNF and no deeper: a retirement tombstone is a published `throw`
      # by design (gen-scope's `buildNodes`), so a deep force is red on a healthy tree.
      lib =
        let
          surface = import ./lib;
        in
        builtins.deepSeq (builtins.mapAttrs (_: builtins.typeOf) surface) surface;
    };
}
