{ lib, genAlgebra, ... }:
let
  R = genAlgebra.lib.record;
  r = R.fromAttrs {
    port = 8080;
    hostname = "localhost";
  };
in
{
  flake.tests.rec-row.test-satisfies-true = {
    expr = R.satisfies r [
      "port"
      "hostname"
    ];
    expected = true;
  };

  flake.tests.rec-row.test-satisfies-false = {
    expr = R.satisfies r [
      "port"
      "missing"
    ];
    expected = false;
  };

  flake.tests.rec-row.test-satisfies-empty-requirements = {
    expr = R.satisfies r [ ];
    expected = true;
  };

  flake.tests.rec-row.test-satisfies-empty-record = {
    expr = R.satisfies R.empty [ "x" ];
    expected = false;
  };

  flake.tests.rec-row.test-assertSatisfies-passes = {
    expr = R.emit (R.assertSatisfies r [ "port" ]);
    expected = {
      port = 8080;
      hostname = "localhost";
    };
  };

  flake.tests.rec-row.test-assertSatisfies-throws = {
    expr = builtins.tryEval (
      R.assertSatisfies r [
        "port"
        "missing"
      ]
    );
    expected = {
      success = false;
      value = false;
    };
  };
}
