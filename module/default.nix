{ lib }:
let
  identity = import ./identity.nix { inherit lib; };
  validate = import ./validate.nix { inherit lib; };
  strict = import ./strict.nix { inherit lib; };
  refType = import ./ref-type.nix { inherit lib; };
in
{
  inherit (identity) mkIdentityModule;
  inherit (validate) mkValidator runValidators formatErrors defaultOnError;
  inherit (strict) mkStrictModule;
  inherit (refType) mkRefType;
}
