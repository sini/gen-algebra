{ lib, genLib, ... }:
let
  inherit (genLib) mkIntensional intensionalEq;
in
{
  flake.tests.intensional.test-mkIntensional-is-callable = {
    expr =
      let
        fn = mkIntensional "add1" { } (x: x + 1);
      in
      fn 5;
    expected = 6;
  };

  flake.tests.intensional.test-mkIntensional-name-field = {
    expr = (mkIntensional "myFn" { x = 1; } (a: a)).name;
    expected = "myFn";
  };

  flake.tests.intensional.test-mkIntensional-closure-preserved = {
    expr =
      (mkIntensional "myFn" {
        x = 1;
        y = 2;
      } (a: a)).closure;
    expected = {
      x = 1;
      y = 2;
    };
  };

  flake.tests.intensional.test-intensionalEq-same-key = {
    expr = intensionalEq (mkIntensional "same" { } (x: x)) (
      mkIntensional "same" { different = true; } (y: y)
    );
    expected = true;
  };

  flake.tests.intensional.test-intensionalEq-different-key = {
    expr = intensionalEq (mkIntensional "a" { } (x: x)) (mkIntensional "b" { } (x: x));
    expected = false;
  };
}
