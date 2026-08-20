# THE SYSTEM LIST, DECLARED HERE BECAUSE THE HARNESS'S DEFAULT NO LONGER NAMES THIS MACHINE.
#
# `gen-harness`'s flakeModule sets `systems = lib.systems.flakeExposed`, and that `lib` is
# flake-parts' BUNDLED `nixpkgs-lib` — the harness's own nixpkgs, never `ci/`'s. Nixpkgs removed
# `x86_64-darwin` from `flakeExposed` after the 26.05 branch-off, so the harness's list is nine
# systems and an Intel mac is not among them. The attribute was never GENERATED, which is why the
# failure reads as a missing `devShells.x86_64-darwin.default` rather than an evaluation error.
#
# ★ THIS ADDS, IT DOES NOT REPLACE. flake-parts' `systems` is a `listOf str`, and the module
# system concatenates list definitions — every system the harness names keeps its outputs, and
# this file supplies the one name it stopped supplying. Written as a module rather than as an
# argument to `mkCi` because `mkCi` has no `systems` parameter; `extraModules` is its extension
# point and this is what that point is for.
{ ... }:
{
  systems = [ "x86_64-darwin" ];
}
