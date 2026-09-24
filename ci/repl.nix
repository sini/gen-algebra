# gen-algebra REPL — all exports in scope. Run: nix repl --impure --file ci/repl.nix
#
# The root is nullary (`{ }:`, den-hoag-iev2q) and gen-algebra takes no nixpkgs `lib`, so it is
# called with `{ }`; `lib` rides beside the surface for convenience only. It is a parameter so
# `ci/tests/repl.nix` can load this entry purely — `nix repl --file` fills the default.
{
  lib ? (builtins.getFlake "nixpkgs").lib,
}:
{ inherit lib; } // import ./.. { }
