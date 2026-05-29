{ lib, genAlgebra, ... }:
let
  inherit (genAlgebra) either;
in
{
  flake.tests.either.test-right-constructor = {
    expr = either.right 42;
    expected = {
      right = 42;
    };
  };

  flake.tests.either.test-left-constructor = {
    expr = either.left "err";
    expected = {
      left = "err";
    };
  };

  flake.tests.either.test-mapR-on-right = {
    expr = either.mapR (x: x * 2) (either.right 5);
    expected = {
      right = 10;
    };
  };

  flake.tests.either.test-mapR-on-left = {
    expr = either.mapR (x: x * 2) (either.left "err");
    expected = {
      left = "err";
    };
  };

  flake.tests.either.test-chain-on-right = {
    expr = either.chain (x: either.right (x + 1)) (either.right 10);
    expected = {
      right = 11;
    };
  };

  flake.tests.either.test-chain-on-left = {
    expr = either.chain (x: either.right (x + 1)) (either.left "err");
    expected = {
      left = "err";
    };
  };

  flake.tests.either.test-chain-right-to-left = {
    expr = either.chain (_: either.left "fail") (either.right 10);
    expected = {
      left = "fail";
    };
  };

  flake.tests.either.test-pipe-all-right = {
    expr = either.pipe [
      (x: either.right (x + 1))
      (x: either.right (x * 2))
    ] 5;
    expected = {
      right = 12;
    };
  };

  flake.tests.either.test-pipe-short-circuits = {
    expr = either.pipe [
      (x: either.right (x + 1))
      (_: either.left "stop")
      (_: either.right 999)
    ] 5;
    expected = {
      left = "stop";
    };
  };

  flake.tests.either.test-pipe-empty-fns = {
    expr = either.pipe [ ] 42;
    expected = {
      right = 42;
    };
  };

  flake.tests.either.test-collectErrors-all-pass = {
    expr = either.collectErrors [
      (x: either.right x)
      (x: either.right (x + 1))
    ] 5;
    expected = {
      right = 5;
    };
  };

  flake.tests.either.test-collectErrors-accumulates = {
    expr = either.collectErrors [
      (_: either.left "e1")
      (x: either.right x)
      (_: either.left "e2")
    ] 5;
    expected = {
      left = [
        "e1"
        "e2"
      ];
    };
  };

  flake.tests.either.test-collectErrors-single-failure = {
    expr = either.collectErrors [
      (_: either.left "only-error")
    ] 5;
    expected = {
      left = [ "only-error" ];
    };
  };
}
