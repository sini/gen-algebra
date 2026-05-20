{ lib ? null }:
let
  pure = import ./pure;
  module = if lib != null then import ./module { inherit lib; } else null;
  noLib = name: throw "gen.${name} requires lib — call (import gen { inherit lib; })";
  moduleFallback = {
    mkIdentityModule = noLib "mkIdentityModule";
    mkValidator = noLib "mkValidator";
    runValidators = noLib "runValidators";
    formatErrors = noLib "formatErrors";
    defaultOnError = noLib "defaultOnError";
    mkStrictModule = noLib "mkStrictModule";
    mkRefType = noLib "mkRefType";
  };
in
pure // (if module != null then module else moduleFallback)
