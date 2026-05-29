{ lib, genAlgebra, ... }:
let
  inherit (genAlgebra) mkStrictModule;
  eval = lib.evalModules {
    modules = [
      (mkStrictModule "host")
      { options.name = lib.mkOption { type = lib.types.str; }; }
      {
        config.name = "igloo";
        config.badKey = "oops";
      }
    ];
  };
  threw = builtins.tryEval (builtins.deepSeq eval.config eval.config);
in
{
  flake.tests.strict.test-undeclared-key-throws = {
    expr = threw.success;
    expected = false;
  };
  flake.tests.strict.test-declared-key-works = {
    expr =
      (lib.evalModules {
        modules = [
          (mkStrictModule "host")
          { options.name = lib.mkOption { type = lib.types.str; }; }
          { config.name = "igloo"; }
        ];
      }).config.name;
    expected = "igloo";
  };
}
