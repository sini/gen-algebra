# Purity invariant — gen-algebra's library source uses no module-system
# primitives. Enforces the pure-algebra-root contract from the gen ecosystem
# purity audit (gen-specs/gen-prelude/2026-06-26-gen-ecosystem-purity-audit.md §5,
# "Gates"). The module tier (mkIdentityModule/mkStrictModule/validators/mkRefType)
# relocated to gen-schema; a stray lib.types/mkOption/evalModules creeping back
# into lib/ or default.nix fails here.
{ lib, genAlgebraSrc, ... }:
let
  # `mkOption` as an infix also catches `mkOptionType`.
  forbidden = [
    "lib.types"
    "mkOption"
    "evalModules"
  ];

  # Library source = default.nix + everything under lib/. ci/ and examples/
  # legitimately use the module system (tests/demos) and are out of scope.
  pureFiles =
    let
      entries = builtins.readDir (genAlgebraSrc + "/lib");
      isNix = n: t: t == "regular" && lib.hasSuffix ".nix" n;
    in
    map (n: genAlgebraSrc + "/lib/${n}") (builtins.attrNames (lib.filterAttrs isNix entries));

  sourceFiles = [ (genAlgebraSrc + "/default.nix") ] ++ pureFiles;

  violations = lib.concatMap (
    file:
    let
      content = builtins.readFile file;
    in
    lib.concatMap (tok: lib.optional (lib.hasInfix tok content) "${baseNameOf file}: ${tok}") forbidden
  ) sourceFiles;
in
{
  flake.tests.purity.test-no-module-primitives = {
    expr = violations;
    expected = [ ];
  };
  flake.tests.purity.test-source-scanned = {
    # default.nix + the lib/ tier (≥6 files) — guards against an empty scan.
    expr = builtins.length sourceFiles >= 6;
    expected = true;
  };
}
