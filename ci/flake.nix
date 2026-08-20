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
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{ gen-harness, gen-identity, ... }:
    let
      genAlgebra = import ../lib;
      genIdentity = gen-identity.lib;
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-algebra";
      testModules = ./tests;
      specialArgs = { inherit genAlgebra genIdentity; };
    };
}
