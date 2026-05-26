{ lib ? null }:
let
  pure = import ./pure;
  module = if lib != null then import ./module { inherit lib; } else null;
  noLib = name: throw "gen-algebra.${name} requires lib — call (import gen-algebra { inherit lib; })";
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
{ pure = pure; } // pure // (if module != null then module else moduleFallback)
