# THE SECOND TEST OUTPUT — cells whose `expr` raises, read by `nix-unit --flake ./ci#testsError`.
# This file lives OUTSIDE `./tests` (the whole of `testModules`), wired through `extraModules` in
# ./flake.nix: the batch asserter behind checks.default forces every `flake.tests` expr and would
# crash on these rather than fail a cell.
#
# Every cell pins a refusal BY NAME (a ThrownError and its message prefix), so an input that
# regresses to an uncatchable TypeError or to a silently accepted value reds here. Each carries a
# live control, wrapped in tryEval so the control cannot itself throw the pinned message.
{ genAlgebra, genIdentity, ... }:
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
    test-unknown-strategy-defaults-only-refuses-by-name = {
      expr =
        assert ok record.foldNestedLayers {
          strategies.q = "replace";
          defaults.q = 1;
          layers = [ ];
        } { q = 1; };
        record.foldNestedLayers {
          strategies.q = "BOGUS";
          defaults.q = 1;
          layers = [ ];
        };
      expectedError = {
        type = "ThrownError";
        msg = "rec.foldNestedLayers: unknown strategy 'BOGUS' at 'q'";
      };
    };
  };

  flake.testsError.rec-fold-layers-refusals =
    flatStrategyCells "foldLayers" { } (r: r)
    // flatStrategyCells "foldLayersTraced" { layerNames = [ "l0" ]; } (r: r.value);

  # P2, R7 (b): `record.combine` takes one record, and a missing field (absent or misspelt) or a stale
  # positional call is refused BY NAME, catchably. The live control: the well-formed record combines.
  flake.testsError.rec-combine-refusals =
    let
      e = record.fromAttrs { x = 1; };
      ctl = ok (args: record.labels (record.combine args)) {
        left = e;
        right = e;
      } [ "x" ];
      req = "\\(required: 'left', 'right'\\) \\(in gen-algebra\\.checkRequired\\)$";
      missing = "^gen-algebra\\.record\\.combine: required field 'right' is missing ${req}";
    in
    {
      test-combine-missing-field-refused = {
        expr =
          assert ctl;
          record.combine { left = e; };
        expectedError = {
          type = "ThrownError";
          msg = missing;
        };
      };
      test-combine-misspelt-field-refused = {
        expr =
          assert ctl;
          record.combine {
            left = e;
            rihgt = e;
          };
        expectedError = {
          type = "ThrownError";
          msg = missing;
        };
      };
      test-combine-stale-positional-refused = {
        # The retired shape `combine a b`: a record is a set, so its first operand is read as the
        # door's record and refused for the field it lacks.
        expr =
          assert ctl;
          record.combine e e;
        expectedError = {
          type = "ThrownError";
          msg = "^gen-algebra\\.record\\.combine: required field 'left' is missing ${req}";
        };
      };
    };

  # `sealedCollisionEq`'s refusal names the components that differ, and a component holding one
  # shared lambda on both sides is not among them, on every evaluator. The live control: the pair
  # that shares every component decides `true`.
  flake.testsError.intensional-cplus-refusals =
    let
      inherit (genAlgebra) componentsPreimage sealedCollisionEq;
      subject = f: g: {
        name = "thing";
        mark = "m";
        sealed =
          (componentsPreimage genIdentity.hashIdentity [
            {
              path = [ "f" ];
              value = f;
              sealed = true;
            }
            {
              path = [ "g" ];
              value = g;
              sealed = true;
            }
          ]).sealed;
      };
      shared = x: x;
      ctl = ok (_: sealedCollisionEq "s" (subject shared shared) (subject shared shared)) null true;
    in
    {
      test-collision-names-only-the-differing-component = {
        expr =
          assert ctl;
          sealedCollisionEq "s" (subject shared (x: x)) (subject shared (y: y));
        expectedError = {
          type = "ThrownError";
          msg = "only at sealed component\\(s\\) 'g': ";
        };
      };
      # Two separate constructions of one declaration hold equal values, and are still refused: the
      # text says the seal is the whole value under `==`, never that the values differ.
      test-two-constructions-with-equal-values-refused-by-name =
        let
          construct = _: subject shared (x: x);
        in
        {
          expr =
            assert ctl;
            sealedCollisionEq "s" (construct 1) (construct 2);
          expectedError = {
            type = "ThrownError";
            msg = "^s: two declarations of 'thing' mint one identity and are unequal only at sealed component\\(s\\) 'g': a sealed component is compared by its seal, the whole value under Nix `==`, where two separately built functions are never equal, so two separate constructions are refused even where the values they compute are equal; a sealed component has no identity, because identity is minted from inert structure alone: migrate it to a first-order term, a registered constructor over inert arguments, so that it mints$";
          };
        };
    };

  # `markOf` refuses BY NAME on a value carrying no mark, where `.minted` raw aborts uncatchably.
  flake.testsError.mark-refusals.test-markOf-without-a-mark-refuses-by-name = {
    expr =
      assert ok genAlgebra.markOf { __mint.minted = "m"; } "m";
      genAlgebra.markOf { __mint.unmintable.reason = "r"; };
    expectedError = {
      type = "ThrownError";
      msg = "^gen-algebra: markOf: the value carries no mark \\(no `__mint` with a `minted` arm\\); a set is not a value its producer minted. Decide with `hasMark` before demanding the mark.$";
    };
  };

  # ★ THE WITNESS DECLARATION IS READ, AND A FORGED OR MALFORMED ONE IS REFUSED BY NAME. `w` is completed
  # the way gen-types and gen-schema complete their values: a completion stamp, and a `check` published
  # beside its witness. A `//` copy keeps the mark, so a copy that re-declares the witness must not be
  # read as `holds`, and a declaration that is not a record of field names must refuse rather than
  # reach a type error. Every cell carries the live control `conservativeEq w w`.
  flake.testsError.witness-refusals =
    let
      inherit (genAlgebra) conservativeEq identityOf;
      completed =
        r:
        let
          s = r // {
            self = _: s;
            __witness = {
              completion = "self";
              checks.check = "checkWitness";
            };
          };
        in
        s;
      check = {
        __functor = self: self.fn;
        fn = x: x == 1;
      };
      w = completed {
        name = "w";
        __mint.minted = "m:w";
        inherit check;
        checkWitness = check;
      };
      ctl = ok (_: conservativeEq w w) null true;
      refusal = why: {
        type = "ThrownError";
        msg = "^gen-algebra: conservativeEq: `w' is not the value its producer completed: ${why}; build the change through its producer$";
      };
      malformed = fault: refusal "it carries a malformed witness declaration: ${fault}";
    in
    {
      test-a-copy-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq w (w // { verify = _: null; });
        expectedError = refusal "a `//` over it keeps its mark while changing what the mark stands for";
      };
      test-a-copy-redeclaring-a-completion-it-does-not-carry-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq w (
            w
            // {
              verify = _: null;
              __witness.completion = "nope";
            }
          );
        expectedError = refusal "it declares its completion witness `nope' and carries no function there, so its mark's claim cannot be checked";
      };
      test-a-value-dropping-its-declared-completion-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq w (removeAttrs w [ "self" ]);
        expectedError = refusal "it declares its completion witness `self' and carries no function there, so its mark's claim cannot be checked";
      };
      test-a-copy-declaring-no-completion-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq w (
            w
            // {
              verify = _: null;
              __witness = { };
            }
          );
        expectedError = malformed "its `__witness` declares no `completion`, so its mark's claim cannot be checked";
      };
      test-a-null-declaration-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq w (
            w
            // {
              verify = _: null;
              __witness = null;
            }
          );
        expectedError = malformed "its `__witness` is a null, not a record of field names";
      };
      test-a-completion-that-is-not-a-field-name-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq w (w // { __witness.completion = 5; });
        expectedError = malformed "its `__witness.completion` is a int, not a field name";
      };
      test-a-check-witness-that-is-not-a-field-name-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq w (
            w
            // {
              __witness = {
                completion = "self";
                checks.check = 5;
              };
            }
          );
        expectedError = malformed "its `__witness.checks` is not a record of field names";
      };
      test-checks-that-are-not-a-record-are-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq w (
            w
            // {
              __witness = {
                completion = "self";
                checks = 5;
              };
            }
          );
        expectedError = malformed "its `__witness.checks` is not a record of field names";
      };
      test-identityOf-refuses-a-malformed-declaration-by-name = {
        expr =
          assert ok identityOf w { minted = "m:w"; };
          identityOf (w // { __witness.checks = 5; });
        expectedError = {
          type = "ThrownError";
          msg = "^gen-algebra: identityOf: `w' carries a malformed witness declaration: its `__witness.checks` is not a record of field names; ";
        };
      };
    };

  # ★ A `//` COPY OF A REGISTERED CONSTRUCTION IS NOT THE VALUE ITS PRODUCER COMPLETED (den-hoag-28dnv).
  # `mkIntensional` declares its completion witness, so a copy that keeps the declared subject while
  # changing the value is refused by name, never decided by the subject it carried over. One cell per
  # `//` shape: an extension, another construction's subject carried over (the field set unchanged), an
  # operand rewritten, the behaviour rewritten. On the component route (`componentsPreimage` into
  # `sealedCollisionEq`) a departed construction is refused at an EQUAL subject, the pair `x` against
  # itself and two self-including extensions included, never compared as its record. Every cell carries
  # the live control: two constructions of one term decide `true`.
  flake.testsError.construction-departures =
    let
      inherit (genAlgebra)
        conservativeEq
        comparisonSubject
        componentsPreimage
        sealedCollisionEq
        ;
      mk = genAlgebra.mkIntensional genIdentity.hashIdentity {
        revision = 1;
        members.mk = a: { marks = [ (toString a) ]; };
      } "mk";
      t1 = mk 1;
      t2 = mk 2;
      x = t1 // {
        note = "x";
      };
      selfIncluding =
        let
          s = t1 // {
            includes = [ s ];
          };
        in
        s;
      ctl = ok (_: conservativeEq t1 (mk 1)) null true;
      compCtl = ok (_: sealedCollisionEq "probe" (composite t1) (composite (mk 1))) null true;
      departure = {
        type = "ThrownError";
        msg = "^probe: 'k' holds component\\(s\\) 'c' that are not the value their producer completed: a `//` over it keeps its mark while changing what the mark stands for; build the change through its producer$";
      };
      refusal = {
        type = "ThrownError";
        msg = "^gen-algebra: conservativeEq: `mk' is not the value its producer completed: a `//` over it keeps its mark while changing what the mark stands for; build the change through its producer$";
      };
      composite =
        v:
        let
          p = componentsPreimage genIdentity.hashIdentity [
            {
              path = [ "c" ];
              value = v;
            }
          ];
        in
        {
          name = "k";
          mark = genIdentity.hashIdentity "k" [ "tags" ] (_: p.tags);
          inherit (p) sealed;
        };
      # a minted component carrying a sealed map, the shape a type over a type hands up
      propagating = v: {
        __mint.minted = "m";
        __sealed = (composite v).sealed;
      };
    in
    {
      test-two-extensions-of-one-construction-are-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq (t1 // { includes = [ "A" ]; }) (t1 // { includes = [ "B" ]; });
        expectedError = refusal;
      };
      test-another-constructions-subject-carried-over-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq t1 (t2 // { inherit (t1) __mint; });
        expectedError = refusal;
      };
      test-a-rewritten-operand-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq t1 (t1 // { args = 2; });
        expectedError = refusal;
      };
      test-a-rewritten-behaviour-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq t1 (t1 // { __functor = _: _: { marks = [ "other" ]; }; });
        expectedError = refusal;
      };
      test-a-departed-component-against-itself-is-refused-by-name = {
        expr =
          assert compCtl;
          sealedCollisionEq "probe" (composite x) (composite x);
        expectedError = departure;
      };
      test-two-equal-departed-components-are-refused-by-name = {
        expr =
          assert compCtl;
          sealedCollisionEq "probe" (composite (t1 // { note = "x"; })) (composite (t1 // { note = "x"; }));
        expectedError = departure;
      };
      test-two-self-including-departed-components-are-refused-by-name = {
        expr =
          assert compCtl;
          sealedCollisionEq "probe" (composite selfIncluding) (
            composite (
              let
                s = t1 // {
                  includes = [ s ];
                };
              in
              s
            )
          );
        expectedError = departure;
      };
      test-a-rewritten-operand-is-refused-by-name-on-the-component-route = {
        expr =
          assert compCtl;
          sealedCollisionEq "probe" (composite t1) (composite (t1 // { args = 2; }));
        expectedError = departure;
      };
      # one level down: a minted component propagates a sealed map holding the departed entry
      test-a-departed-component-one-level-down-is-refused-by-name = {
        expr =
          assert compCtl;
          sealedCollisionEq "probe" (composite (propagating (t1 // { includes = [ "A" ]; }))) (
            composite (propagating (t1 // { includes = [ "B" ]; }))
          );
        expectedError = departure;
      };
      # a projection has no second operand: a departed value's subject is refused, never its record
      test-the-subject-of-a-departed-construction-is-refused-by-name = {
        expr =
          assert ctl;
          comparisonSubject selfIncluding == comparisonSubject (
            let
              s = t1 // {
                includes = [ s ];
              };
            in
            s
          );
        expectedError = {
          type = "ThrownError";
          msg = "^gen-algebra: comparisonSubject: `mk' is not the value its producer completed: a `//` over it keeps its mark while changing what the mark stands for; build the change through its producer$";
        };
      };
      # the witness slot removed: a declared subject without it is refused, never read as a record
      test-a-declared-subject-without-its-witness-is-refused-by-name = {
        expr =
          assert ctl;
          conservativeEq (removeAttrs selfIncluding [ "__witness" ]) (
            removeAttrs (
              let
                s = t1 // {
                  includes = [ s ];
                };
              in
              s
            ) [ "__witness" ]
          );
        expectedError = {
          type = "ThrownError";
          msg = "^gen-algebra: conservativeEq: `mk' is not the value its producer completed: it carries a malformed witness declaration: it declares a comparison subject and no `__witness`, so its subject's claim cannot be checked; build the change through its producer$";
        };
      };
    };
}
