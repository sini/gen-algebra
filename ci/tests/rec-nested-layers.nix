{ lib, genAlgebra, ... }:
let
  inherit (genAlgebra) record;
in
{
  flake.tests.rec-nested-layers = {
    test-flatten-simple = {
      expr = record.flattenAttrs { } {
        a.b = 1;
        a.c = 2;
        d = 3;
      };
      expected = {
        "a.b" = 1;
        "a.c" = 2;
        "d" = 3;
      };
    };

    test-flatten-deep = {
      expr = record.flattenAttrs { } { x.y.z = "deep"; };
      expected = {
        "x.y.z" = "deep";
      };
    };

    test-flatten-with-prefix = {
      expr = record.flattenAttrs { prefix = "ns"; } {
        a = 1;
        b = 2;
      };
      expected = {
        "ns.a" = 1;
        "ns.b" = 2;
      };
    };

    test-flatten-recursive-strategy-halts = {
      expr =
        record.flattenAttrs
          {
            strategies = {
              "a.b" = "recursive";
            };
          }
          {
            a.b = {
              x = 1;
              y = 2;
            };
            a.c = 3;
          };
      expected = {
        "a.b" = {
          x = 1;
          y = 2;
        };
        "a.c" = 3;
      };
    };

    test-flatten-empty = {
      expr = record.flattenAttrs { } { };
      expected = { };
    };

    test-unflatten-simple = {
      expr = record.unflattenAttrs {
        "a.b" = 1;
        "a.c" = 2;
        "d" = 3;
      };
      expected = {
        a = {
          b = 1;
          c = 2;
        };
        d = 3;
      };
    };

    test-unflatten-deep = {
      expr = record.unflattenAttrs { "x.y.z" = "deep"; };
      expected = {
        x.y.z = "deep";
      };
    };

    test-unflatten-empty = {
      expr = record.unflattenAttrs { };
      expected = { };
    };

    test-roundtrip =
      let
        original = {
          a.b = 1;
          a.c = 2;
          d = 3;
        };
        flat = record.flattenAttrs { } original;
      in
      {
        expr = record.unflattenAttrs flat;
        expected = {
          a = {
            b = 1;
            c = 2;
          };
          d = 3;
        };
      };

    test-fold-nested-replace = {
      expr = record.foldNestedLayers {
        layers = [
          {
            a.b = "low";
            a.c = "only-low";
          }
          { a.b = "high"; }
        ];
      };
      expected = {
        a = {
          b = "high";
          c = "only-low";
        };
      };
    };

    test-fold-nested-append = {
      expr = record.foldNestedLayers {
        strategies = {
          "a.items" = "append";
        };
        layers = [
          { a.items = [ "base" ]; }
          { a.items = [ "override" ]; }
        ];
      };
      expected = {
        a.items = [
          "base"
          "override"
        ];
      };
    };

    test-fold-nested-recursive = {
      expr = record.foldNestedLayers {
        strategies = {
          "a.config" = "recursive";
        };
        layers = [
          {
            a.config = {
              x = 1;
            };
          }
          {
            a.config = {
              y = 2;
            };
          }
        ];
      };
      expected = {
        a.config = {
          x = 1;
          y = 2;
        };
      };
    };

    test-fold-nested-defaults = {
      expr = record.foldNestedLayers {
        defaults = {
          a.b = "default";
          a.c = "default-c";
        };
        layers = [
          { a.b = "override"; }
        ];
      };
      expected = {
        a = {
          b = "override";
          c = "default-c";
        };
      };
    };

    test-fold-nested-empty-layers = {
      expr = record.foldNestedLayers {
        defaults = {
          x = 1;
        };
        layers = [ ];
      };
      expected = {
        x = 1;
      };
    };
  };
}
