{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";
    # nixpkgs is the CI runner's dependency (test harness, treefmt) and supplies the
    # `lib` the test modules use. gen-algebra itself (../lib) takes no inputs.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{ gen-harness, ... }:
    let
      genAlgebra = import ../lib;
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-algebra";
      testModules = ./tests;
      specialArgs = { inherit genAlgebra; };
    };
}
