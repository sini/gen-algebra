{ lib, genAlgebra, ... }:
let
  inherit (genAlgebra) record;

  # Round-trip fixtures for the key encoding. `tilde` and `empty-nested-vs-top` are the
  # only fixtures that red the two plausible wrong fixes — escaping "." but not "~", and
  # keeping "" as the root sentinel — so they stay verbatim.
  roundTripFixtures = {
    plain = {
      a.b = 1;
      a.c = 2;
      d = 3;
    };
    dotted-top = {
      "a.b" = 1;
    };
    collision = {
      "a.b" = 1;
      a.b = 2;
    };
    dotted-deep = {
      x."y.z".w = 1;
      x.y.z.w = 2;
    };
    empty-top = {
      "" = 1;
    };
    empty-nested-vs-top = {
      "" = {
        x = 1;
      };
      x = 2;
    };
    empty-inner = {
      a."" = 1;
      "a." = 2;
    };
    tilde = {
      "~" = 1;
      "a~1b" = 2;
      "a.b" = 3;
    };
    unicode = {
      "é.ü"."日本" = 1;
      "é"."ü"."日本" = 2;
      "ß" = 3;
    };
    empty-set-leaf = {
      a = { };
      b.c = 1;
    };
    empty = { };
  };

  refused =
    key: !(builtins.tryEval (builtins.deepSeq (record.unflattenAttrs { ${key} = 1; }) true)).success;

  # One segment alphabet over the escape's edge cases: "~", both escapes, ".", "", a key
  # that is itself an escape sequence, unicode, a newline, a trailing "~".
  segmentAlphabet = [
    "~"
    "~0"
    "~1"
    "."
    ".."
    ""
    "~01"
    "a~"
    "é.ü"
    "日本"
    "x\ny"
    "~~"
    "~.~"
    "a"
  ];

  # Three layers at a.b whose suffix pre-folded differs from the whole (qif85 cells).
  L0 = {
    a.b = 5;
  };
  L1 = {
    a.b.x = 1;
  };
  L2 = {
    a.b.y = 9;
  };
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

    # A key containing "." and the nested path it spells are two leaves, not one.
    test-flatten-dotted-key-no-collision = {
      expr = record.flattenAttrs { } {
        "a.b" = 1;
        a.b = 2;
      };
      expected = {
        "a~1b" = 1;
        "a.b" = 2;
      };
    };

    # unflatten ∘ flatten is the identity; the value is the list of fixtures it fails on.
    test-roundtrip-identity-fixtures = {
      expr = builtins.filter (
        n: record.unflattenAttrs (record.flattenAttrs { } roundTripFixtures.${n}) != roundTripFixtures.${n}
      ) (builtins.attrNames roundTripFixtures);
      expected = [ ];
    };

    test-fold-nested-dotted-key-no-collision = {
      expr = record.foldNestedLayers {
        layers = [
          { "a.b" = "literal"; }
          { a.b = "nested"; }
        ];
      };
      expected = {
        "a.b" = "literal";
        a.b = "nested";
      };
    };

    # A strategy for a segment containing "." is keyed by its escape.
    test-flatten-strategy-escaped-key = {
      expr = record.flattenAttrs { strategies."a~1b" = "recursive"; } {
        "a.b".p = 1;
      };
      expected = {
        "a~1b" = {
          p = 1;
        };
      };
    };

    # A "~" not followed by 0 or 1 is outside the escape's image, and decoding it
    # leniently would merge { "~" = 1; "~0" = 2; } into one path.
    test-unflatten-refuses-non-canonical-segment = {
      expr = map refused [
        "~"
        "a~"
        "~2"
        "a~2b"
        "~~"
      ];
      expected = [
        true
        true
        true
        true
        true
      ];
    };

    test-unflatten-refuses-non-canonical-inner-segment = {
      expr = refused "ok.a~2b.ok";
      expected = true;
    };

    # Every escaped segment is accepted and decodes to itself.
    test-unflatten-accepts-every-escape = {
      expr = builtins.filter (
        s:
        refused (builtins.replaceStrings [ "~" "." ] [ "~0" "~1" ] s)
        || record.unflattenAttrs (record.flattenAttrs { } { ${s} = 1; }) != { ${s} = 1; }
      ) segmentAlphabet;
      expected = [ ];
    };

    # Control: foldLayers never flattens, so the encoding leaves it untouched. The
    # layered record mirrors gen-demo's C13 construct (all three strategies + defaults).
    test-fold-layers-control-unchanged = {
      expr = record.foldLayers {
        strategies = {
          tacks = "append";
          meta = "recursive";
        };
        defaults = {
          gauge = "fine";
        };
        layers = [
          {
            spool = "linen";
            tacks = [ "a" ];
            meta.warp = 1;
          }
          {
            spool = "sateen";
            tacks = [ "b" ];
            meta.weft = 2;
          }
        ];
      };
      expected = {
        gauge = "fine";
        meta = {
          warp = 1;
          weft = 2;
        };
        spool = "sateen";
        tacks = [
          "a"
          "b"
        ];
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

    # Layer order over shape (den-hoag-qif85): the last layer providing a path wins whatever
    # its shape. A non-attrset resets the path; later attrsets merge onto what the reset left.
    test-fold-nested-scalar-over-subtree = {
      expr = record.foldNestedLayers {
        layers = [
          { a.b.x = 1; }
          { a.b = 5; }
        ];
      };
      expected = {
        a.b = 5;
      };
    };
    test-fold-nested-null-over-subtree = {
      expr = record.foldNestedLayers {
        layers = [
          { a.b.x = 1; }
          { a.b = null; }
        ];
      };
      expected = {
        a.b = null;
      };
    };
    test-fold-nested-three-layer-reset = {
      expr = record.foldNestedLayers {
        layers = [
          { a.b.x = 1; }
          { a.b = 5; }
          { a.b.y = 9; }
        ];
      };
      expected = {
        a.b.y = 9;
      };
    };
    test-fold-nested-scalar-over-default-subtree = {
      expr = record.foldNestedLayers {
        defaults.a.b.x = 1;
        layers = [ { a.b = 5; } ];
      };
      expected = {
        a.b = 5;
      };
    };
    # The reset at a.b discards the items appended before it.
    test-fold-nested-append-after-reset = {
      expr = record.foldNestedLayers {
        strategies."a.b.items" = "append";
        layers = [
          { a.b.items = [ 1 ]; }
          { a.b = 5; }
          { a.b.items = [ 2 ]; }
        ];
      };
      expected = {
        a.b.items = [ 2 ];
      };
    };

    # Regression guards: a node-wholesale reading (the last value at any shape conflict wins
    # verbatim) is not a fold of any step and fails these; the left fold passes them.
    test-fold-nested-default-shape-does-not-split-layers = {
      expr =
        map
          (
            d:
            record.foldNestedLayers {
              defaults.a.b = d;
              layers = [
                { a.b.x = 1; }
                { a.b.y = 2; }
              ];
            }
          )
          [
            null
            5
          ];
      expected = [
        {
          a.b = {
            x = 1;
            y = 2;
          };
        }
        {
          a.b = {
            x = 1;
            y = 2;
          };
        }
      ];
    };
    test-fold-nested-earlier-scalar-does-not-split-later-layers = {
      expr = record.foldNestedLayers {
        layers = [
          L0
          L1
          L2
        ];
      };
      expected = {
        a.b = {
          x = 1;
          y = 9;
        };
      };
    };
    # The action law: a pre-folded prefix, resumed as defaults or as a layer, changes nothing.
    test-fold-nested-prefix-invariance = {
      expr = {
        asSeed =
          record.foldNestedLayers {
            defaults = record.foldNestedLayers {
              layers = [
                L0
                L1
              ];
            };
            layers = [ L2 ];
          } == record.foldNestedLayers {
            layers = [
              L0
              L1
              L2
            ];
          };
        asLayer =
          record.foldNestedLayers {
            layers = [
              (record.foldNestedLayers {
                layers = [
                  L0
                  L1
                ];
              })
              L2
            ];
          } == record.foldNestedLayers {
            layers = [
              L0
              L1
              L2
            ];
          };
      };
      expected = {
        asSeed = true;
        asLayer = true;
      };
    };
    test-fold-nested-empty-set-keeps-default = {
      expr = record.foldNestedLayers {
        defaults.logging.level = "info";
        layers = [ { logging = { }; } ];
      };
      expected = {
        logging.level = "info";
      };
    };
    test-fold-nested-empty-set-keeps-subtree = {
      expr = record.foldNestedLayers {
        layers = [
          { a.b.x = 1; }
          { a.b = { }; }
        ];
      };
      expected = {
        a.b.x = 1;
      };
    };

    # Laziness: a value the fold discards is never forced (the required-default idiom).
    test-fold-nested-overridden-default-is-not-forced = {
      expr = record.foldNestedLayers {
        defaults.a.b = throw "a.b is required";
        layers = [ { a.b = 5; } ];
      };
      expected = {
        a.b = 5;
      };
    };
    test-fold-nested-reset-layer-value-is-not-forced = {
      expr = record.foldNestedLayers {
        layers = [
          { a.b = throw "unset"; }
          { a.b = 5; }
          { a.b.x = 1; }
        ];
      };
      expected = {
        a.b.x = 1;
      };
    };

    # Controls: the same value before and after den-hoag-qif85.
    test-fold-nested-subtree-over-scalar = {
      expr = record.foldNestedLayers {
        layers = [
          { a.b = 5; }
          { a.b.x = 1; }
        ];
      };
      expected = {
        a.b.x = 1;
      };
    };
    test-fold-nested-scalar-over-empty-set = {
      expr = record.foldNestedLayers {
        layers = [
          { a.b = { }; }
          { a.b = 5; }
        ];
      };
      expected = {
        a.b = 5;
      };
    };
    test-fold-nested-empty-set-over-scalar = {
      expr = record.foldNestedLayers {
        layers = [
          { a.b = 5; }
          { a.b = { }; }
        ];
      };
      expected = {
        a.b = { };
      };
    };
    test-fold-nested-empty-root-layer = {
      expr = record.foldNestedLayers {
        layers = [
          { a.b.x = 1; }
          { }
        ];
      };
      expected = {
        a.b.x = 1;
      };
    };
  };
}
