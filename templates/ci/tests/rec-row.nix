{ lib, genLib, ... }:
let
  R = genLib.pure.record;
  r = R.fromAttrs { port = 8080; hostname = "localhost"; };
in
{
  rec-row.test-satisfies-true = {
    expr = R.satisfies r [ "port" "hostname" ];
    expected = true;
  };

  rec-row.test-satisfies-false = {
    expr = R.satisfies r [ "port" "missing" ];
    expected = false;
  };

  rec-row.test-satisfies-empty-requirements = {
    expr = R.satisfies r [ ];
    expected = true;
  };

  rec-row.test-satisfies-empty-record = {
    expr = R.satisfies R.empty [ "x" ];
    expected = false;
  };

  rec-row.test-assertSatisfies-passes = {
    expr = R.emit (R.assertSatisfies r [ "port" ]);
    expected = {
      port = 8080;
      hostname = "localhost";
    };
  };

  rec-row.test-assertSatisfies-throws = {
    expr = builtins.tryEval (R.assertSatisfies r [ "port" "missing" ]);
    expected = {
      success = false;
      value = false;
    };
  };
}
