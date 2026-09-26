# THE SECOND TEST OUTPUT — cells whose `expr` raises, read by `nix-unit --flake ./ci#testsError`.
# This file lives OUTSIDE `./tests` (the whole of `testModules`), wired through `extraModules` in
# ./flake.nix: the batch asserter behind checks.default forces every `flake.tests` expr and would
# crash on these rather than fail a cell.
#
# Every cell pins a refusal BY NAME (a ThrownError and its message prefix), so an input that
# regresses to an uncatchable TypeError or to a silently accepted value reds here. Each carries a
# live control, wrapped in tryEval so the control cannot itself throw the pinned message.
{ genAlgebra, ... }:
let
  inherit (genAlgebra) record;

  ok =
    f: args: expected:
    let
      c = builtins.tryEval (builtins.deepSeq (f args) (f args));
    in
    c.success && c.value == expected;

  # One value of each non-string kind a strategy could be given by mistake.
  nonStringStrategies = {
    int = 1;
    float = 1.5;
    bool = true;
    null = null;
    list = [ ];
    set = { };
    lambda = y: y;
  };

  # The flat folds render a non-string strategy in their unknown-strategy refusal rather than
  # interpolating it, which aborted uncatchably for every kind above.
  flatStrategyCells =
    fold: extra: valueOf:
    builtins.listToAttrs (
      map (kind: {
        name = "test-${fold}-${kind}-strategy-refuses-by-name";
        value = {
          expr =
            assert ok (args: valueOf (record.${fold} args)) (
              extra
              // {
                strategies.x = "replace";
                layers = [ { x = 1; } ];
              }
            ) { x = 1; };
            builtins.deepSeq (record.${fold} (
              extra
              // {
                strategies.x = nonStringStrategies.${kind};
                layers = [ { x = 1; } ];
              }
            )) null;
          expectedError = {
            type = "ThrownError";
            msg = "rec.${fold}: unknown strategy '<a ${kind}>' for field 'x'";
          };
        };
      }) (builtins.attrNames nonStringStrategies)
    );
in
{
  flake.testsError.rec-nested-layers-refusals = {
    test-append-over-attrset-refuses-by-name = {
      expr =
        assert ok record.foldNestedLayers
          {
            strategies."a.b" = "append";
            layers = [
              { a.b = [ 1 ]; }
              { a.b = [ 2 ]; }
            ];
          }
          {
            a.b = [
              1
              2
            ];
          };
        record.foldNestedLayers {
          strategies."a.b" = "append";
          layers = [
            { a.b.x = 1; }
            { a.b.x = 2; }
          ];
        };
      expectedError = {
        type = "ThrownError";
        msg = "rec.foldNestedLayers: strategy 'append' at 'a.b' needs a list";
      };
    };
    test-recursive-over-scalar-refuses-by-name = {
      expr =
        assert ok record.foldNestedLayers
          {
            strategies."a.b" = "recursive";
            layers = [
              { a.b.x = 1; }
              { a.b.y = 2; }
            ];
          }
          {
            a.b = {
              x = 1;
              y = 2;
            };
          };
        record.foldNestedLayers {
          strategies."a.b" = "recursive";
          layers = [
            { a.b.x = 1; }
            { a.b = 5; }
          ];
        };
      expectedError = {
        type = "ThrownError";
        msg = "rec.foldNestedLayers: strategy 'recursive' at 'a.b' needs an attrset";
      };
    };
    test-non-attrset-layer-refuses-by-name = {
      expr =
        assert ok record.foldNestedLayers { layers = [ { a = 1; } ]; } { a = 1; };
        record.foldNestedLayers {
          layers = [
            { a = 1; }
            null
          ];
        };
      expectedError = {
        type = "ThrownError";
        msg = "rec.foldNestedLayers: layer 1 is a value of type null";
      };
    };
    test-non-attrset-defaults-refuses-by-name = {
      expr =
        assert ok record.foldNestedLayers {
          defaults.a = 0;
          layers = [ { a = 1; } ];
        } { a = 1; };
        record.foldNestedLayers {
          defaults = null;
          layers = [ { a = 1; } ];
        };
      expectedError = {
        type = "ThrownError";
        msg = "rec.foldNestedLayers: defaults is a value of type null";
      };
    };
    test-non-list-layers-refuses-by-name = {
      expr =
        assert ok record.foldNestedLayers { layers = [ ]; } { };
        record.foldNestedLayers { layers.a = 1; };
      expectedError = {
        type = "ThrownError";
        msg = "rec.foldNestedLayers: layers is a value of type set, not a list";
      };
    };
    test-non-attrset-strategies-refuses-by-name = {
      expr =
        assert ok record.foldNestedLayers {
          strategies = { };
          layers = [ { a = 1; } ];
        } { a = 1; };
        record.foldNestedLayers {
          strategies = null;
          layers = [ { a = 1; } ];
        };
      expectedError = {
        type = "ThrownError";
        msg = "rec.foldNestedLayers: strategies is a value of type null, not an attrset";
      };
    };
    test-non-string-strategy-refuses-by-name = {
      expr =
        assert ok record.foldNestedLayers {
          strategies."a.b" = "replace";
          layers = [ { a.b = 1; } ];
        } { a.b = 1; };
        record.foldNestedLayers {
          strategies."a.b" = y: y;
          layers = [ { a.b = 1; } ];
        };
      expectedError = {
        type = "ThrownError";
        msg = "rec.foldNestedLayers: unknown strategy '<a lambda>' at 'a.b'";
      };
    };
  };

  flake.testsError.rec-fold-layers-refusals =
    flatStrategyCells "foldLayers" { } (r: r)
    // flatStrategyCells "foldLayersTraced" { layerNames = [ "l0" ]; } (r: r.value);
}
