{ lib }:
let
  mkValidator = name: pred: message: {
    inherit name pred message;
  };

  runValidators =
    kind: validators: instances:
    let
      failures = lib.concatLists (
        lib.mapAttrsToList (
          name: instance:
          lib.concatMap (
            v:
            if v.pred instance then
              [ ]
            else
              [
                {
                  inherit kind name;
                  validator = v.name;
                  inherit (v) message;
                }
              ]
          ) validators
        ) instances
      );
    in
    if failures == [ ] then { right = instances; } else { left = failures; };

  formatErrors =
    failures:
    lib.concatMapStringsSep "\n" (
      f: "  ${f.kind} '${f.name}': ${f.validator} — ${f.message}"
    ) failures;

  defaultOnError =
    left:
    if builtins.isList left then
      throw "schema validation failed:\n${formatErrors left}"
    else
      throw "gen: unexpected validation error: ${builtins.toJSON left}";
in
{
  inherit mkValidator runValidators formatErrors defaultOnError;
}
