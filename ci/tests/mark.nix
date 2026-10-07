# gen-algebra: the MARK readers, `hasMark` (the decision) and `markOf` (the demand).
#
# A mark is not an identity. A value carrying a mark beside a non-empty `__sealed` is on the
# compared arm of `identityOf`, and its mark is still what a key over mark AND sealed subjects
# reads. These cells pin both halves on one fixture: the mark answers where the identity does not.
{ genAlgebra, genIdentity, ... }:
let
  inherit (genAlgebra)
    hasMark
    markOf
    identityOf
    regimeTagOf
    mkIntensional
    ;
  refuses = e: !(builtins.tryEval e).success;

  digest = genIdentity.hashIdentity "fixture" [ "value" ] (_: "k");
  unsealed = {
    __mint.minted = digest;
    __sealed = { };
  };
  # The shape a gen-schema kind with an option default has: a mark, and a sealed component.
  sealed = {
    __mint.minted = digest;
    __sealed."open.options.port.default" = 22;
  };
  registered = mkIntensional genIdentity.hashIdentity {
    revision = "r1";
    members.addN = args: x: x + args.n;
  } "addN" { n = 1; };
in
{
  # The sealed fixture: the mark answers its digest while `identityOf` answers the compared arm.
  flake.tests.mark.test-a-mark-beside-sealed-components-answers-where-identity-does-not = {
    expr = {
      has = hasMark sealed;
      mark = markOf sealed;
      regime = regimeTagOf (identityOf sealed);
    };
    expected = {
      has = true;
      mark = digest;
      regime = "s";
    };
  };

  # Where nothing is sealed the two readers agree.
  flake.tests.mark.test-unsealed-mark-is-the-identity = {
    expr = identityOf unsealed == { minted = markOf unsealed; };
    expected = true;
  };

  # The decision is total over values carrying no mark, and the demand refuses on each of them.
  flake.tests.mark.test-no-mark-decides-false-and-demand-refuses = {
    expr =
      map
        (v: {
          has = hasMark v;
          demandRefuses = refuses (markOf v);
        })
        [
          registered
          { name = "unmigrated"; }
          { __mint = "not a record"; }
          "a string"
          null
        ];
    expected = builtins.genList (_: {
      has = false;
      demandRefuses = true;
    }) 5;
  };

  # The decision forces the mark RECORD and never the digest.
  flake.tests.mark.test-decision-never-forces-the-digest = {
    expr = hasMark { __mint.minted = throw "digest forced"; };
    expected = true;
  };
}
