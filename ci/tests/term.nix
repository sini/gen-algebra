# The term algebra's gating cells (den-hoag-lwbb1 unit 1), from ../term-cells.nix.
{ genAlgebra, genIdentity, ... }:
{
  flake.tests.term = builtins.listToAttrs (
    map (n: {
      name = "test-${n}";
      value = (import ../term-cells.nix { inherit genAlgebra genIdentity; }).${n};
    }) (builtins.attrNames (import ../term-cells.nix { inherit genAlgebra genIdentity; }))
  );
}
