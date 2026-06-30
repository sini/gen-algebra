{
  inputs = {
    gen.url = "github:sini/gen";
    # nixpkgs is the CI runner's dependency (test harness, treefmt) and supplies the
    # `lib` the test modules use. gen-algebra itself (../lib) takes no inputs.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{ gen, ... }:
    let
      genAlgebra = import ../lib;
    in
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-algebra";
      testModules = ./tests;
      specialArgs = { inherit genAlgebra; };
    };
}
