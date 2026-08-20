{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";

    # ★ CI'S INPUTS ARE CI'S OWN, AND THAT IS A RULING RATHER THAN A CONVENIENCE. The
    # zero-inputs contract binds the LIBRARY — `../lib` and the root flake — because what it
    # protects is a CONSUMER's closure, and a consumer resolves `../lib`, never this lock. Owner-
    # ruled 2026-08-20 (den-hoag-soa1), verbatim: "ci/ has its own flake."
    #
    # So the suite takes the REAL mint. It used to inject a stand-in, which could carry the
    # constructor's arms and nothing else — the encoder's domain, its bounds and its refusals were
    # asserted only where the encoder lives, and the end-to-end composition was untested by
    # construction. gen-identity has no inputs of its own, so this costs the runner one leaf.
    gen-identity.url = "github:sini/gen-identity";

    # nixpkgs is the CI runner's dependency (test harness, treefmt) and supplies the
    # `lib` the test modules use.
    #
    # ★ PINNED TO 26.05, AND THE PIN IS WHAT KEEPS x86_64-darwin ALIVE. Nixpkgs 26.11 does not
    # merely drop that platform from `lib.systems.flakeExposed` — `legacyPackages.x86_64-darwin`
    # THROWS, so an Intel mac cannot resolve a single package from unstable. 26.05 is the last
    # release carrying the platform (security fixes to end-2026), which dates this line: when the
    # last Intel machine goes, this returns to `nixos-unstable` and `./systems.nix` is deleted
    # with it.
    #
    # ★ ONE nixpkgs FOR EVERY SYSTEM, deliberately. A second, darwin-only input would keep the
    # rest of the toolchain current at the price of this machine evaluating a different `lib`
    # than the GitHub runner does — local green, CI red, in a suite that asserts byte identity.
    # One lock is the property worth more than a current treefmt.
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen-harness,
      gen-identity,
      nixpkgs,
      ...
    }:
    let
      genAlgebra = import ../lib;
      genIdentity = gen-identity.lib;

      # nix-unit FOR ONE SYSTEM, and it is a PATCH of the harness's value rather than an input of
      # our own.
      #
      # `mkCi`'s `resolve` reads `(resolve "nix-unit").packages.${system}.default` for both the
      # devshell package and the pre-commit `ci` hook. The harness's nix-unit is built from the
      # same shrunken `flakeExposed`, so that attribute is absent on x86_64-darwin and
      # `./systems.nix` alone would trade a missing devShell for a missing attribute. Declaring
      # our own `nix-unit` input does NOT fix it either: its system list comes from ITS
      # flake-parts, which no `inputs.nixpkgs.follows` reaches.
      #
      # What does carry the platform is this flake's own nixpkgs, which ships `nix-unit` as an
      # ordinary package. So the harness's value is extended for exactly the one system it lacks
      # — every other system keeps the upstream flake's package, byte for byte.
      upstreamNixUnit = gen-harness.inputs.nix-unit;
      nixUnit = upstreamNixUnit // {
        packages = upstreamNixUnit.packages // {
          x86_64-darwin.default = nixpkgs.legacyPackages.x86_64-darwin.nix-unit;
        };
      };
    in
    gen-harness.lib.mkCi {
      # `resolve` prefers a consumer's tool over the harness's, which is the documented override
      # path and the reason the patch above lands by passing `inputs` rather than by forking the
      # harness.
      inputs = inputs // {
        nix-unit = nixUnit;
      };
      name = "gen-algebra";
      testModules = ./tests;
      specialArgs = { inherit genAlgebra genIdentity; };
      extraModules = [ ./systems.nix ];
    };
}
