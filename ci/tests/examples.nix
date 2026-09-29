{ lib, genAlgebra, ... }:
{
  gen.ci.examples.demo = (import ../../examples/demo/flake.nix).outputs {
    gen-algebra.lib = genAlgebra;
    nixpkgs.lib = lib;
  };
}
