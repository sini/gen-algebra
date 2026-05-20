let
  search = import ./search.nix;
  intensional = import ./intensional.nix;
in
{
  inherit search;
  inherit (intensional) mkIntensional intensionalEq;
}
