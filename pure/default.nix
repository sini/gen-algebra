let
  search = import ./search.nix;
  either = import ./either.nix;
  intensional = import ./intensional.nix;
  identity = import ./identity.nix;
  primitives = import ./primitives;
in
{
  inherit search either primitives;
  inherit (intensional) mkIntensional intensionalEq;
  inherit (identity) mkIdentity;
}
