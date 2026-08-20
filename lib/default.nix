let
  search = import ./search.nix;
  either = import ./either.nix;
  intensional = import ./intensional.nix;
  record = import ./rec.nix;
in
{
  inherit search either record;

  # `conservativeEq` is Palmer's own term for this relation (§2.3, §5.3, §8): "intensional"
  # qualifies the FUNCTION, never the equality. The old export name read as a licence to compare
  # intension alone, which is exactly the half of Fig. 5's conjunction the relation used to ship.
  #
  # `identityOf` and its three siblings are exported because a consumer that DECIDES must dispatch
  # on the regime tag rather than reading `__mint` raw — a value with no mintable identity carries
  # the field and not the `minted` arm, so a raw read aborts uncatchably instead of refusing.
  inherit (intensional)
    mkIntensional
    conservativeEq
    identityOf
    regimeTagOf
    isExact
    comparisonSubject
    ;
}
