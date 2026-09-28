{ lib, genAlgebra, ... }:
let
  R = genAlgebra.record;
  r = R.fromAttrs {
    port = 8080;
    hostname = "localhost";
  };
in
{
  flake.tests.rec-row.test-satisfies-true = {
    expr = R.satisfies [
      "port"
      "hostname"
    ] r;
    expected = true;
  };

  flake.tests.rec-row.test-satisfies-false = {
    expr = R.satisfies [
      "port"
      "missing"
    ] r;
    expected = false;
  };

  flake.tests.rec-row.test-satisfies-empty-requirements = {
    expr = R.satisfies [ ] r;
    expected = true;
  };

  flake.tests.rec-row.test-satisfies-empty-record = {
    expr = R.satisfies [ "x" ] R.empty;
    expected = false;
  };

  flake.tests.rec-row.test-assertSatisfies-passes = {
    expr = R.emit (R.assertSatisfies [ "port" ] r);
    expected = {
      port = 8080;
      hostname = "localhost";
    };
  };

  flake.tests.rec-row.test-assertSatisfies-throws = {
    expr = builtins.tryEval (
      R.assertSatisfies [
        "port"
        "missing"
      ] r
    );
    expected = {
      success = false;
      value = false;
    };
  };
}
