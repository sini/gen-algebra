{ lib, genAlgebra, ... }:
let
  R = genAlgebra.record;
in
{
  flake.tests.rec-primitives.test-empty = {
    expr = R.empty;
    expected = {
      __entries = { };
      __order = [ ];
    };
  };

  flake.tests.rec-primitives.test-extend-new-label = {
    expr = R.extend "x" 42 R.empty;
    expected = {
      __entries = {
        x = [ 42 ];
      };
      __order = [ "x" ];
    };
  };

  flake.tests.rec-primitives.test-extend-existing-label-pushes-stack = {
    expr = R.extend "x" 2 (R.extend "x" 1 R.empty);
    expected = {
      __entries = {
        x = [
          2
          1
        ];
      };
      __order = [ "x" ];
    };
  };

  flake.tests.rec-primitives.test-extend-preserves-order = {
    expr = (R.extend "b" 2 (R.extend "a" 1 R.empty)).__order;
    expected = [
      "a"
      "b"
    ];
  };

  flake.tests.rec-primitives.test-select-returns-head = {
    expr = R.select "x" (R.extend "x" 2 (R.extend "x" 1 R.empty));
    expected = 2;
  };

  flake.tests.rec-primitives.test-select-throws-on-absent = {
    expr = builtins.tryEval (R.select "x" R.empty);
    expected = {
      success = false;
      value = false;
    };
  };

  flake.tests.rec-primitives.test-restrict-pops-stack = {
    expr = R.restrict "x" (R.extend "x" 2 (R.extend "x" 1 R.empty));
    expected = {
      __entries = {
        x = [ 1 ];
      };
      __order = [ "x" ];
    };
  };

  flake.tests.rec-primitives.test-restrict-removes-label-when-stack-empty = {
    expr = R.restrict "x" (R.extend "x" 1 R.empty);
    expected = {
      __entries = { };
      __order = [ ];
    };
  };

  flake.tests.rec-primitives.test-restrict-noop-on-absent = {
    expr = R.restrict "x" R.empty;
    expected = R.empty;
  };

  flake.tests.rec-primitives.test-scoped-label-roundtrip = {
    expr =
      let
        r = R.extend "x" 2 (R.extend "x" 1 R.empty);
      in
      R.select "x" (R.restrict "x" r);
    expected = 1;
  };

  flake.tests.rec-primitives.test-has-true = {
    expr = R.has "x" (R.extend "x" 1 R.empty);
    expected = true;
  };

  flake.tests.rec-primitives.test-has-false = {
    expr = R.has "x" R.empty;
    expected = false;
  };

  flake.tests.rec-primitives.test-depth-with-values = {
    expr = R.depth "x" (R.extend "x" 2 (R.extend "x" 1 R.empty));
    expected = 2;
  };

  flake.tests.rec-primitives.test-depth-absent = {
    expr = R.depth "x" R.empty;
    expected = 0;
  };
}
