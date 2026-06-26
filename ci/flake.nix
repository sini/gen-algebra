{
  inputs = {
    gen.url = "github:sini/gen";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{ gen, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      genAlgebra = import ../. { inherit lib; };
    in
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-algebra";
      testModules = ./tests;
      # genAlgebraSrc: repo root, for the purity invariant (ci/tests/purity.nix)
      # to scan library source for module-system primitives.
      specialArgs = {
        inherit genAlgebra;
        genAlgebraSrc = ../.;
      };
    };
}
