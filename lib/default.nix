let
  search = import ./search.nix;
  either = import ./either.nix;
  intensional = import ./intensional.nix;
  record = import ./rec.nix;
in
{
  inherit search either record;
  inherit (intensional) mkIntensional intensionalEq;
}
