let
  search = import ./search.nix;
  either = import ./either.nix;
  intensional = import ./intensional.nix;
  identity = import ./identity.nix;
  recLib = import ./rec.nix;
in
{
  inherit search either;
  record = recLib;
  inherit (intensional) mkIntensional intensionalEq;
  inherit (identity) mkIdentity;
}
