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
  };
}
