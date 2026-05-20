let
  search = import ./search.nix;
  either = import ./either.nix;
  intensional = import ./intensional.nix;
  identity = import ./identity.nix;
in
{
  inherit search either;
  inherit (intensional) mkIntensional intensionalEq;
  inherit (identity) mkIdentity;
}
