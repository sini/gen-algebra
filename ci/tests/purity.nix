# Purity invariant (gen ecosystem purity audit §5): gen-algebra's library source uses no
# nixpkgs.lib and no module-system primitives — it is builtins + its own domain algebra.
# A stray `lib.foo` / `lib.types` / `evalModules` / nixpkgs input creeping back into the
# library source fails CI. The module tier relocated to gen-schema.
#
# Scope: lib/**.nix (recursively) + the root flake.nix + default.nix. NOT ci/ — the test
# harness legitimately uses nixpkgs.lib (including, here, to do this scan).
#
# Forbidden list omits `gen-algebra`/`genAlgebra` (this IS gen-algebra; the flake
# description names it).
{ genPrelude, lib, ... }:
let
  libDir = ../../lib;

  # Comment-stripped source: drop everything from the first `#` on each line. Safe here
  # because `#` appears only in comments across these files (no `#` in string literals).
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  # Recursively collect every .nix under a directory.
  walk =
    dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "directory" then
          walk (dir + "/${name}")
        else if lib.hasSuffix ".nix" name then
          [ (dir + "/${name}") ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  sources =
    map (p: {
      name = toString p;
      code = stripComments (builtins.readFile p);
    }) (walk libDir)
    ++
      map
        (rel: {
          name = rel;
          code = stripComments (builtins.readFile (../.. + "/${rel}"));
        })
        [
          "flake.nix"
          "default.nix"
        ];

  # Tokens signalling a nixpkgs-lib tether or the module-system (Korora-class) tier.
  forbidden = [
    "nixpkgs"
    "lib."
    "{ lib }"
    "{ lib,"
    "evalModules"
    "mkOption"
  ];

  violations = lib.concatMap (
    src:
    map (tok: "${src.name}: '${tok}'") (lib.filter (tok: genPrelude.hasInfix tok src.code) forbidden)
  ) sources;
in
{
  flake.tests.purity.test-library-source-is-nixpkgs-lib-free = {
    expr = violations;
    expected = [ ];
  };
}
