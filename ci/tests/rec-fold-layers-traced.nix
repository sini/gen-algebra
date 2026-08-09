{ lib, genAlgebra, ... }:
let
  inherit (genAlgebra.record) foldLayers foldLayersTraced;

  # A replace fixture (multiple contributors + a passthrough key).
  replaceArgs = {
    strategies = { };
    defaults = {
      port = 80;
    };
    layers = [
      {
        port = 443;
        extra = "bonus";
      }
      { port = 8080; }
    ];
    layerNames = [
      "l0"
      "l1"
    ];
  };

  # An append fixture with a default list.
  appendArgs = {
    strategies = {
      tags = "append";
    };
    defaults = {
      tags = [ "base" ];
    };
    layers = [
      { tags = [ "ssl" ]; }
      { tags = [ "web" ]; }
    ];
    layerNames = [
      "l0"
      "l1"
    ];
  };

  # A recursive fixture with overlapping + disjoint subkeys.
  recursiveArgs = {
    strategies = {
      x = "recursive";
    };
    defaults = {
      x = { };
    };
    layers = [
      {
        x = {
          a = 1;
          b = 3;
        };
      }
      {
        x = {
          a = 2;
          c = 4;
        };
      }
    ];
    layerNames = [
      "l0"
      "l1"
    ];
  };

  # A semilattice-set fixture: overlapping list values, ACI union.
  semilatticeArgs = {
    strategies = {
      f = "semilattice-set";
    };
    defaults = {
      f = [ ];
    };
    layers = [
      {
        f = [
          "a"
          "b"
          "c"
        ];
      }
      {
        f = [
          "b"
          "c"
          "d"
        ];
      }
    ];
    layerNames = [
      "l0"
      "l1"
    ];
  };

  # The same two layers, folded in the reversed order (the permutation witness).
  semilatticeArgsRev = {
    strategies = {
      f = "semilattice-set";
    };
    defaults = {
      f = [ ];
    };
    layers = [
      {
        f = [
          "b"
          "c"
          "d"
        ];
      }
      {
        f = [
          "a"
          "b"
          "c"
        ];
      }
    ];
    layerNames = [
      "l1"
      "l0"
    ];
  };

  # The two shared-domain shapes the three fixtures above miss: `replace` declared
  # EXPLICITLY (the others reach it only by omission) and a field carried by `defaults`
  # alone, which no layer contributes.
  explicitReplaceArgs = {
    strategies = {
      port = "replace";
    };
    defaults = {
      port = 80;
      workers = 4;
    };
    layers = [
      { port = 443; }
      { port = 8080; }
    ];
    layerNames = [
      "l0"
      "l1"
    ];
  };

  # A caller-owned per-entry refinement, domain-free: the derived reading is a thunk, and
  # for one designated value it diverges. This stands in for a consumer whose refinement
  # follows a reference the entry carries and whose target is absent.
  diverging = "DIVERGING";
  refineArgs = {
    defaults = {
      f = diverging;
    };
    layers = [ { f = "wins"; } ];
    layerNames = [ "l0" ];
    entryTransform = field: entry: {
      inherit (entry) layer;
      inherit field;
      derived =
        if entry.value == diverging then throw "rec-test: entry refinement diverged" else entry.value;
    };
  };
  refineChain = (foldLayersTraced refineArgs).provenance.f;

  sortStrs = builtins.sort builtins.lessThan;

  stripTrace =
    args:
    removeAttrs args [
      "layerNames"
      "defaultLabel"
    ];
in
{
  flake.tests.rec-fold-layers-traced = {
    # --- Value-identity guard: .value must equal foldLayers exactly. ---

    test-value-identity-replace = {
      expr = (foldLayersTraced replaceArgs).value == foldLayers (stripTrace replaceArgs);
      expected = true;
    };

    test-value-identity-append = {
      expr = (foldLayersTraced appendArgs).value == foldLayers (stripTrace appendArgs);
      expected = true;
    };

    test-value-identity-recursive = {
      expr = (foldLayersTraced recursiveArgs).value == foldLayers (stripTrace recursiveArgs);
      expected = true;
    };

    # The domain the guard names is the whole of what both siblings accept, so it has to
    # include the explicitly-declared `replace` and the no-contribution path, not only the
    # shapes the strategy-specific fixtures happen to exercise.
    test-value-identity-explicit-replace-and-default-only = {
      expr = (foldLayersTraced explicitReplaceArgs).value == foldLayers (stripTrace explicitReplaceArgs);
      expected = true;
    };

    # --- replace, multiple contributors: ordered default-first provenance. ---

    test-replace-provenance-order = {
      expr = (foldLayersTraced replaceArgs).provenance.port;
      expected = [
        {
          layer = "default";
          value = 80;
        }
        {
          layer = "l0";
          value = 443;
        }
        {
          layer = "l1";
          value = 8080;
        }
      ];
    };

    # The last entry is the effective contributor; default is informational.
    test-replace-last-effective = {
      expr =
        let
          prov = (foldLayersTraced replaceArgs).provenance.port;
          last = lib.last prov;
        in
        {
          inherit (last) layer value;
          headIsDefault = (builtins.head prov).layer == "default";
        };
      expected = {
        layer = "l1";
        value = 8080;
        headIsDefault = true;
      };
    };

    # --- replace, no contribution: value == default, lone default entry. ---

    test-replace-no-contribution = {
      expr =
        let
          res = foldLayersTraced {
            strategies = { };
            defaults = {
              port = 80;
              workers = 4;
            };
            layers = [ { port = 8080; } ];
            layerNames = [ "l0" ];
          };
        in
        {
          value = res.value.workers;
          provenance = res.provenance.workers;
        };
      expected = {
        value = 4;
        provenance = [
          {
            layer = "default";
            value = 4;
          }
        ];
      };
    };

    # --- append with default: value == default-list ++ contributors, default-led. ---

    test-append-provenance = {
      expr = (foldLayersTraced appendArgs).provenance.tags;
      expected = [
        {
          layer = "default";
          value = [ "base" ];
        }
        {
          layer = "l0";
          value = [ "ssl" ];
        }
        {
          layer = "l1";
          value = [ "web" ];
        }
      ];
    };

    test-append-value = {
      expr = (foldLayersTraced appendArgs).value.tags;
      expected = [
        "base"
        "ssl"
        "web"
      ];
    };

    # --- recursive: provenance shows each layer's whole attrset. ---

    test-recursive-provenance = {
      expr = (foldLayersTraced recursiveArgs).provenance.x;
      expected = [
        {
          layer = "default";
          value = { };
        }
        {
          layer = "l0";
          value = {
            a = 1;
            b = 3;
          };
        }
        {
          layer = "l1";
          value = {
            a = 2;
            c = 4;
          };
        }
      ];
    };

    test-recursive-value = {
      expr = (foldLayersTraced recursiveArgs).value.x;
      expected = {
        a = 2;
        b = 3;
        c = 4;
      };
    };

    # --- pure-null field: a field that resolves to null still gets a
    # non-empty provenance entry. ---
    # The literal `!hasContrib && !hasDefault` sentinel branch is provably
    # unreachable for any key in allKeys: allKeys = attrNames(defaults) ∪
    # (keys of each layer), so every resolved key is either in defaults
    # (hasDefault) or contributed by a layer (hasContrib). That branch is a
    # defensive guard for out-of-band `resolve` calls. The observable
    # contract — a null-valued field yields a non-empty, default-led
    # provenance — is exercised here via `defaults.<f> = null`, which is the
    # closest natural construction.
    test-pure-null-default = {
      expr =
        let
          res = foldLayersTraced {
            strategies = { };
            defaults = {
              maybe = null;
            };
            layers = [ ];
            layerNames = [ ];
          };
        in
        {
          value = res.value.maybe;
          provenance = res.provenance.maybe;
        };
      expected = {
        value = null;
        provenance = [
          {
            layer = "default";
            value = null;
          }
        ];
      };
    };

    # --- length-mismatch throws. ---

    test-length-mismatch-throws = {
      expr =
        (builtins.tryEval (foldLayersTraced {
          layers = [ { } ];
          layerNames = [ ];
        })).success;
      expected = false;
    };

    # --- semilattice-set: commutative + idempotent set-union of list values. ---

    # Deduped union: default [ ] ++ l0 ["a" "b" "c"], then l1 contributes only
    # "d" (b/c already present) → ["a" "b" "c" "d"] in insertion order.
    test-semilattice-union-dedup = {
      expr = (foldLayersTraced semilatticeArgs).value.f;
      expected = [
        "a"
        "b"
        "c"
        "d"
      ];
    };

    # ACI witness: the SAME layers folded in BOTH orders yield the same set
    # (list order follows insertion, so equality is witnessed on the sorted set).
    test-semilattice-permutation-invariant = {
      expr =
        let
          fwd = (foldLayersTraced semilatticeArgs).value.f;
          rev = (foldLayersTraced semilatticeArgsRev).value.f;
        in
        sortStrs fwd == sortStrs rev;
      expected = true;
    };

    # Idempotence: re-contributing an identical layer adds nothing new.
    test-semilattice-idempotent = {
      expr =
        (foldLayersTraced {
          strategies.f = "semilattice-set";
          layers = [
            {
              f = [
                "a"
                "b"
              ];
            }
            {
              f = [
                "a"
                "b"
              ];
            }
          ];
          layerNames = [
            "l0"
            "l1"
          ];
        }).value.f;
      expected = [
        "a"
        "b"
      ];
    };

    # Intra-layer dedup: a single layer with an internal duplicate collapses
    # to a set (element-wise fold, not filter-against-fixed-acc).
    test-semilattice-intra-layer-dup = {
      expr =
        (foldLayersTraced {
          strategies.f = "semilattice-set";
          layers = [
            {
              f = [
                "a"
                "a"
                "b"
              ];
            }
          ];
          layerNames = [ "l0" ];
        }).value.f;
      expected = [
        "a"
        "b"
      ];
    };

    # --- unknown strategy throws. ---

    test-unknown-strategy-throws = {
      expr =
        (builtins.tryEval
          (foldLayersTraced {
            strategies.x = "bogus";
            layers = [ { x = 1; } ];
            layerNames = [ "a" ];
          }).value.x
        ).success;
      expected = false;
    };

    # --- entryTransform: the refinement is applied, and NON-INTERFERENCE holds. ---

    # Arming: the transform runs, and it is handed the field name. Every other test in this
    # file omits `entryTransform` entirely, so those are the paired absence readings.
    test-entry-transform-applied = {
      expr = builtins.map (e: {
        inherit (e) layer field;
      }) refineChain;
      expected = [
        {
          layer = "default";
          field = "f";
        }
        {
          layer = "l0";
          field = "f";
        }
      ];
    };

    # Same fixture with the transform removed: the chain is emitted untransformed. Without
    # this arm the tests above could not distinguish the hook from a hard-coded shape.
    test-entry-transform-absent-is-untransformed = {
      expr = (foldLayersTraced (removeAttrs refineArgs [ "entryTransform" ])).provenance.f;
      expected = [
        {
          layer = "default";
          value = "DIVERGING";
        }
        {
          layer = "l0";
          value = "wins";
        }
      ];
    };

    # Empty control: no defaults and no layers ⇒ no fields, so the transform is never
    # reached. It throws unconditionally, so a run that applied it could not report `{ }`,
    # and the non-emptiness the arms above assert is a reading rather than the instrument.
    test-entry-transform-empty = {
      expr =
        (foldLayersTraced { entryTransform = _field: _entry: throw "rec-test: must not run"; }).provenance;
      expected = { };
    };

    # Non-interference — the chain's SPINE is forceable while one entry's refinement diverges.
    test-entry-transform-spine-forceable = {
      expr = builtins.length refineChain;
      expected = 2;
    };

    # Non-interference — the diverging entry's OWN metadata is forceable.
    test-entry-transform-metadata-forceable = {
      expr = (builtins.head refineChain).layer;
      expected = "default";
    };

    # Non-interference — a SIBLING entry's refinement is forceable.
    test-entry-transform-sibling-forceable = {
      expr = (lib.last refineChain).derived;
      expected = "wins";
    };

    # ...and the divergence is real: forcing that entry's own refinement throws. Without
    # this the three arms above would pass against a transform that never diverges.
    test-entry-transform-entry-throws-on-force = {
      expr = (builtins.tryEval (builtins.deepSeq (builtins.head refineChain).derived true)).success;
      expected = false;
    };

    # Non-interference — the value path never applies the transform. A contaminated value
    # would be the transformed record here, not the winning contribution.
    test-entry-transform-value-untouched = {
      expr = (foldLayersTraced refineArgs).value;
      expected = {
        f = "wins";
      };
    };
  };
}
