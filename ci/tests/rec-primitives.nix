{ lib, genAlgebra, ... }:
let
  R = genAlgebra.lib.record;
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
    expr = R.extend R.empty "x" 42;
    expected = {
      __entries = {
        x = [ 42 ];
      };
      __order = [ "x" ];
    };
  };

  flake.tests.rec-primitives.test-extend-existing-label-pushes-stack = {
    expr = R.extend (R.extend R.empty "x" 1) "x" 2;
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
    expr = (R.extend (R.extend R.empty "a" 1) "b" 2).__order;
    expected = [
      "a"
      "b"
    ];
  };

  flake.tests.rec-primitives.test-select-returns-head = {
    expr = R.select (R.extend (R.extend R.empty "x" 1) "x" 2) "x";
    expected = 2;
  };

  flake.tests.rec-primitives.test-select-throws-on-absent = {
    expr = builtins.tryEval (R.select R.empty "x");
    expected = {
      success = false;
      value = false;
    };
  };

  flake.tests.rec-primitives.test-restrict-pops-stack = {
    expr = R.restrict (R.extend (R.extend R.empty "x" 1) "x" 2) "x";
    expected = {
      __entries = {
        x = [ 1 ];
      };
      __order = [ "x" ];
    };
  };

  flake.tests.rec-primitives.test-restrict-removes-label-when-stack-empty = {
    expr = R.restrict (R.extend R.empty "x" 1) "x";
    expected = {
      __entries = { };
      __order = [ ];
    };
  };

  flake.tests.rec-primitives.test-restrict-noop-on-absent = {
    expr = R.restrict R.empty "x";
    expected = R.empty;
  };

  flake.tests.rec-primitives.test-scoped-label-roundtrip = {
    expr =
      let
        r = R.extend (R.extend R.empty "x" 1) "x" 2;
      in
      R.select (R.restrict r "x") "x";
    expected = 1;
  };

  flake.tests.rec-primitives.test-has-true = {
    expr = R.has (R.extend R.empty "x" 1) "x";
    expected = true;
  };

  flake.tests.rec-primitives.test-has-false = {
    expr = R.has R.empty "x";
    expected = false;
  };

  flake.tests.rec-primitives.test-depth-with-values = {
    expr = R.depth (R.extend (R.extend R.empty "x" 1) "x" 2) "x";
    expected = 2;
  };

  flake.tests.rec-primitives.test-depth-absent = {
    expr = R.depth R.empty "x";
    expected = 0;
  };
}
