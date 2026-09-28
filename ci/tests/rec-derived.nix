{ lib, genAlgebra, ... }:
let
  R = genAlgebra.record;
  r = R.extend "y" 2 (R.extend "x" 1 R.empty);
  stacked = R.extend "x" 2 (R.extend "x" 1 R.empty);
in
{
  flake.tests.rec-derived.test-emit = {
    expr = R.emit r;
    expected = {
      x = 1;
      y = 2;
    };
  };

  flake.tests.rec-derived.test-emit-takes-head = {
    expr = R.emit stacked;
    expected = {
      x = 2;
    };
  };

  flake.tests.rec-derived.test-emitAll-full-stacks = {
    expr = R.emitAll [ "x" ] stacked;
    expected = {
      x = [
        2
        1
      ];
    };
  };

  flake.tests.rec-derived.test-emitAll-mixed = {
    expr = R.emitAll [ "x" ] (R.extend "y" 3 stacked);
    expected = {
      x = [
        2
        1
      ];
      y = 3;
    };
  };

  flake.tests.rec-derived.test-fromAttrs = {
    expr = R.fromAttrs {
      a = 1;
      b = 2;
    };
    expected = {
      __entries = {
        a = [ 1 ];
        b = [ 2 ];
      };
      __order = [
        "a"
        "b"
      ];
    };
  };

  flake.tests.rec-derived.test-fromAttrs-roundtrip = {
    expr = R.emit (
      R.fromAttrs {
        a = 1;
        b = 2;
      }
    );
    expected = {
      a = 1;
      b = 2;
    };
  };

  flake.tests.rec-derived.test-update-replaces-head = {
    expr = R.select "x" (R.update "x" 99 stacked);
    expected = 99;
  };

  flake.tests.rec-derived.test-update-preserves-stack-depth = {
    expr = R.depth "x" (R.update "x" 99 stacked);
    expected = 2;
  };

  flake.tests.rec-derived.test-update-throws-on-absent = {
    expr = builtins.tryEval (R.update "x" 1 R.empty);
    expected = {
      success = false;
      value = false;
    };
  };

  flake.tests.rec-derived.test-upsert-inserts-when-absent = {
    expr = R.select "x" (R.upsert "x" 1 R.empty);
    expected = 1;
  };

  flake.tests.rec-derived.test-upsert-replaces-when-present = {
    expr = R.select "x" (R.upsert "x" 2 (R.extend "x" 1 R.empty));
    expected = 2;
  };

  # upsert on a stacked label: restrict pops one, extend pushes one → depth preserved.
  # Semantically identical to update on present labels, but also handles absent labels.
  flake.tests.rec-derived.test-upsert-preserves-stack-depth = {
    expr = R.depth "x" (R.upsert "x" 99 stacked);
    expected = 2;
  };

  flake.tests.rec-derived.test-rename = {
    expr = R.emit (R.rename "old" "new" (R.extend "old" 42 R.empty));
    expected = {
      new = 42;
    };
  };

  flake.tests.rec-derived.test-labels = {
    expr = R.labels r;
    expected = [
      "x"
      "y"
    ];
  };

  flake.tests.rec-derived.test-show = {
    expr = R.show (R.extend "x" 2 (R.extend "x" 1 R.empty));
    expected = "{ x = [2, 1] }";
  };

  flake.tests.rec-derived.test-showCompact = {
    expr = R.showCompact r;
    expected = "{ x = 1; y = 2 }";
  };
}
