{ lib, genAlgebra, ... }:
let
  inherit (genAlgebra) search mkIntensional;
in
{
  flake.tests.search-converge.test-basic = {
    expr =
      let
        s0 = search.insert "k" "v1" search.empty;
        s1 = search.on "k" (v: s: search.emit [ "saw:${v}" ] s) s0;
        final = search.converge s1;
      in
      final.results;
    expected = [ "saw:v1" ];
  };

  flake.tests.search-converge.test-multi-round = {
    expr =
      let
        s0 = search.insert "trigger" "go" search.empty;
        s1 = search.on "trigger" (_v: s: search.insert "data" "from-A" s) s0;
        s2 = search.on "data" (v: s: search.emit [ "B-saw:${v}" ] s) s1;
        final = search.converge s2;
      in
      final.results;
    expected = [ "B-saw:from-A" ];
  };

  flake.tests.search-converge.test-stability = {
    expr =
      let
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" (v: s: search.emit [ v ] s) s0;
        first = search.converge s1;
        second = search.converge first;
      in
      {
        firstResults = first.results;
        secondResults = second.results;
      };
    expected = {
      firstResults = [ "v" ];
      secondResults = [ "v" ];
    };
  };

  flake.tests.search-converge.test-unwatched-key = {
    expr =
      let
        s0 = search.insert "other" "v" search.empty;
        s1 = search.on "missing" (_v: s: search.emit [ "should-not-fire" ] s) s0;
        final = search.converge s1;
      in
      final.results;
    expected = [ ];
  };

  flake.tests.search-converge.test-dynamic-registration = {
    expr =
      let
        s0 = search.insert "phase1" "go" search.empty;
        s1 = search.insert "phase2" "data" s0;
        s2 = search.on "phase1" (
          _v: s: search.on "phase2" (v2: s2: search.emit [ "dynamic:${v2}" ] s2) s
        ) s1;
        final = search.converge s2;
      in
      final.results;
    expected = [ "dynamic:data" ];
  };

  flake.tests.search-converge.test-intensional-dedup = {
    expr =
      let
        counter = mkIntensional "my-counter" { } (v: s: search.emit [ "counted:${v}" ] s);
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" counter s0;
        s2 = search.on "k" counter s1;
        final = search.converge s2;
      in
      final.results;
    expected = [ "counted:v" ];
  };

  flake.tests.search-converge.test-empty = {
    expr = search.converge search.empty;
    expected = search.empty;
  };

  flake.tests.search-converge.test-bounded-self-insert = {
    expr =
      let
        s0 = search.insert "k" "start" search.empty;
        s1 = search.on "k" (
          v: s:
          if v == "start" then
            search.insert "k" "done" (search.emit [ "processed:${v}" ] s)
          else
            search.emit [ "processed:${v}" ] s
        ) s0;
        final = search.converge s1;
      in
      final.results;
    expected = [
      "processed:start"
      "processed:done"
    ];
  };

  flake.tests.search-converge.test-on-before-insert = {
    expr =
      let
        s0 = search.on "k" (v: s: search.emit [ "saw:${v}" ] s) search.empty;
        s1 = search.insert "k" "late-arrival" s0;
        final = search.converge s1;
      in
      final.results;
    expected = [ "saw:late-arrival" ];
  };

  flake.tests.search-converge.test-non-intensional-duplicates-fire-independently = {
    expr =
      let
        fn = v: s: search.emit [ "fired:${v}" ] s;
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" fn s0;
        s2 = search.on "k" fn s1;
        final = search.converge s2;
      in
      final.results;
    expected = [
      "fired:v"
      "fired:v"
    ];
  };

  # ── dedup by identity REGIME ────────────────────────────────────────────────
  # These assert OUTCOMES — which continuations fired — and not keys. Both the
  # sound and the defective accumulator produce the SAME keys for a pair sharing a
  # program point, so a cell that asserted the key would pass on the defect.

  # The witness: two continuations watching one index key, sharing one program
  # point, behaving differently. Under the retired presence loop one of them was
  # dropped body and all — silently. Both must fire.
  flake.tests.search-converge.test-same-name-distinct-bodies-both-fire = {
    expr =
      let
        cont = tag: mkIntensional "shared-point" { inherit tag; } (v: s: search.emit [ "${tag}:${v}" ] s);
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" (cont "A") s0;
        s2 = search.on "k" (cont "B") s1;
      in
      (search.converge s2).results;
    expected = [
      "A:v"
      "B:v"
    ];
  };

  # CONTROL for the cell above: the loop must still MERGE, or the relation is
  # false everywhere and the witness passes for the wrong reason. One value bound
  # once and registered twice is one continuation. (`test-intensional-dedup`
  # asserts the same property through the public constructor.)
  flake.tests.search-converge.test-one-value-registered-twice-fires-once = {
    expr =
      let
        cont = mkIntensional "shared-point" { } (v: s: search.emit [ "once:${v}" ] s);
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" cont s0;
        s2 = search.on "k" cont s1;
      in
      (search.converge s2).results;
    expected = [ "once:v" ];
  };

  # The MINTED arm: a stamped identity is total in the distinguishing content, so
  # its key is exact and presence alone decides. Distinct digests separate.
  flake.tests.search-converge.test-minted-distinct-digests-both-fire = {
    expr =
      let
        cont =
          digest: tag:
          (mkIntensional "shared-point" { } (v: s: search.emit [ "${tag}:${v}" ] s))
          // {
            __mint.minted = digest;
          };
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" (cont "its:aaaa" "X") s0;
        s2 = search.on "k" (cont "its:bbbb" "Y") s1;
      in
      (search.converge s2).results;
    expected = [
      "X:v"
      "Y:v"
    ];
  };

  # CONTROL for the minted arm: one digest is one continuation, whatever the
  # bodies do. An exact key is a dedup key, and this is the merge it must keep.
  flake.tests.search-converge.test-minted-same-digest-fires-once = {
    expr =
      let
        cont =
          tag:
          (mkIntensional "shared-point" { } (v: s: search.emit [ "${tag}:${v}" ] s))
          // {
            __mint.minted = "its:cccc";
          };
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" (cont "X") s0;
        s2 = search.on "k" (cont "Y") s1;
      in
      (search.converge s2).results;
    expected = [ "X:v" ];
  };

  # THE KEY SPACE IS TAGGED BY REGIME, and this is the forgery that forecloses: an
  # unmigrated continuation whose NAME is string-equal to another's minted DIGEST.
  # Untagged, both arms render into one string space, the pair lands on one key and one
  # is dropped — a name forging a digest's identity. Tagged, the arms are disjoint.
  # Asserted in BOTH registration orders, because an order-sensitive drop would
  # otherwise be only half visible.
  flake.tests.search-converge.test-name-cannot-forge-a-minted-key = {
    expr =
      let
        forgedName = "its:aaaa";
        mintedCont = (mkIntensional "counter" { } (v: s: search.emit [ "M:${v}" ] s)) // {
          __mint.minted = forgedName;
        };
        unmigratedCont = mkIntensional forgedName { } (v: s: search.emit [ "U:${v}" ] s);
        run =
          first: second:
          let
            s0 = search.insert "k" "v" search.empty;
          in
          (search.converge (search.on "k" second (search.on "k" first s0))).results;
      in
      {
        mintedFirst = run mintedCont unmigratedCont;
        unmigratedFirst = run unmigratedCont mintedCont;
      };
    expected = {
      mintedFirst = [
        "M:v"
        "U:v"
      ];
      unmigratedFirst = [
        "U:v"
        "M:v"
      ];
    };
  };

  # The UNMINTABLE arm: a value that declares it has no mintable identity must
  # reach the loop and be decided, never abort. A reader that branched on `?
  # __mint` and read `.minted` raw would abort uncatchably here.
  flake.tests.search-converge.test-unmintable-distinct-values-both-fire = {
    expr =
      let
        cont =
          tag:
          (mkIntensional "shared-point" { inherit tag; } (v: s: search.emit [ "${tag}:${v}" ] s))
          // {
            __mint.unmintable = {
              reason = "distinguishing content is a caller-supplied lambda";
              ctor = "shared-point";
            };
          };
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" (cont "A") s0;
        s2 = search.on "k" (cont "B") s1;
      in
      (search.converge s2).results;
    expected = [
      "A:v"
      "B:v"
    ];
  };

  # CONTROL for the cell above, REGIME-MATCHED to it. The merge controls elsewhere in
  # this file are unmigrated-regime values, and a control in one regime cannot show the
  # relation is non-empty in another: without this cell, an unmintable arm that answered
  # "unequal" for every pair would pass the cell above unnoticed. One value registered
  # twice must fire ONCE.
  flake.tests.search-converge.test-unmintable-one-value-registered-twice-fires-once = {
    expr =
      let
        cont = (mkIntensional "shared-point" { } (v: s: search.emit [ "once:${v}" ] s)) // {
          __mint.unmintable = {
            reason = "distinguishing content is a caller-supplied lambda";
            ctor = "shared-point";
          };
        };
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" cont s0;
        s2 = search.on "k" cont s1;
      in
      (search.converge s2).results;
    expected = [ "once:v" ];
  };

  # The sealed arm compares the reified value MINUS `__id`: that accessor is what a
  # consumer reads when it DEMANDS an identity, and where nothing is minted it IS the
  # named refusal. Forcing it inside a bucket scan would detonate the decision the
  # refusal exists to permit, so a poisoned accessor must not disturb dedup at all.
  flake.tests.search-converge.test-sealed-bucket-does-not-force-id = {
    expr =
      let
        cont =
          tag:
          (mkIntensional "shared-point" { inherit tag; } (v: s: search.emit [ "${tag}:${v}" ] s))
          // {
            __mint.unmintable = {
              reason = "distinguishing content is a caller-supplied lambda";
              ctor = "shared-point";
            };
            __id = throw "identity: 'shared-point' has no mintable identity";
          };
        one = cont "S";
        s0 = search.insert "k" "v" search.empty;
        distinct = search.on "k" (cont "B") (search.on "k" (cont "A") s0);
        same = search.on "k" one (search.on "k" one s0);
      in
      {
        distinctBothFire = (search.converge distinct).results;
        sameValueFiresOnce = (search.converge same).results;
      };
    expected = {
      distinctBothFire = [
        "A:v"
        "B:v"
      ];
      sameValueFiresOnce = [ "S:v" ];
    };
  };
}
