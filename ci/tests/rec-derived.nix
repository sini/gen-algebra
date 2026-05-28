{ lib, genLib, ... }:
let
  R = genLib.pure.record;
  r = R.extend (R.extend R.empty "x" 1) "y" 2;
  stacked = R.extend (R.extend R.empty "x" 1) "x" 2;
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
    expr = R.emitAll stacked [ "x" ];
    expected = {
      x = [
        2
        1
      ];
    };
  };

  flake.tests.rec-derived.test-emitAll-mixed = {
    expr = R.emitAll (R.extend stacked "y" 3) [ "x" ];
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
    expr = R.select (R.update stacked "x" 99) "x";
    expected = 99;
  };

  flake.tests.rec-derived.test-update-preserves-stack-depth = {
    expr = R.depth (R.update stacked "x" 99) "x";
    expected = 2;
  };

  flake.tests.rec-derived.test-update-throws-on-absent = {
    expr = builtins.tryEval (R.update R.empty "x" 1);
    expected = {
      success = false;
      value = false;
    };
  };

  flake.tests.rec-derived.test-upsert-inserts-when-absent = {
    expr = R.select (R.upsert R.empty "x" 1) "x";
    expected = 1;
  };

  flake.tests.rec-derived.test-upsert-replaces-when-present = {
    expr = R.select (R.upsert (R.extend R.empty "x" 1) "x" 2) "x";
    expected = 2;
  };

  # upsert on a stacked label: restrict pops one, extend pushes one → depth preserved.
  # Semantically identical to update on present labels, but also handles absent labels.
  flake.tests.rec-derived.test-upsert-preserves-stack-depth = {
    expr = R.depth (R.upsert stacked "x" 99) "x";
    expected = 2;
  };

  flake.tests.rec-derived.test-rename = {
    expr = R.emit (R.rename (R.extend R.empty "old" 42) "old" "new");
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
    expr = R.show (R.extend (R.extend R.empty "x" 1) "x" 2);
    expected = "{ x = [2, 1] }";
  };

  flake.tests.rec-derived.test-showCompact = {
    expr = R.showCompact r;
    expected = "{ x = 1; y = 2 }";
  };
}
