{ lib, genLib, ... }:
let
  inherit (genLib.pure.primitives.math) pow powi abs mod mantissa round;
in
{
  primitives-math.test-pow-base-one = {
    expr = pow 1 100;
    expected = 1;
  };
  primitives-math.test-pow-zero-zero = {
    expr = pow 0 0;
    expected = 1;
  };
  primitives-math.test-powi-basic = {
    expr = powi 2 10;
    expected = 1024;
  };
  primitives-math.test-powi-zero-exp = {
    expr = powi 3 0;
    expected = 1;
  };
  primitives-math.test-abs-intmin-throws = {
    expr = (builtins.tryEval (abs (-9223372036854775807 - 1))).success;
    expected = false;
  };
  primitives-math.test-mod-negative = {
    # C truncation semantics: sign follows dividend
    expr = mod (-7) 3;
    expected = (-1);
  };
  primitives-math.test-mod-zero = {
    expr = mod 0 5;
    expected = 0;
  };
  primitives-math.test-mod-exact = {
    expr = mod 9 3;
    expected = 0;
  };
  primitives-math.test-mantissa-half = {
    expr = mantissa 3.5;
    expected = 0.5;
  };
  primitives-math.test-mantissa-integer = {
    expr = mantissa 4.0;
    expected = 0.0;
  };
  primitives-math.test-round-zero-decimals = {
    expr = round 0 3.7;
    expected = 4.0;
  };
}
