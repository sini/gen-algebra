{ lib, genLib, ... }:
let
  inherit (genLib.pure.primitives.trivial)
    not
    nand
    nor
    xor
    xnor
    imply
    implyDefault
    applyArgs
    applyAutoArgs
    ;
in
{
  primitives-trivial.test-not = {
    expr = not true;
    expected = false;
  };
  primitives-trivial.test-xor-true = {
    expr = xor true false;
    expected = true;
  };
  primitives-trivial.test-xor-false = {
    expr = xor true true;
    expected = false;
  };
  primitives-trivial.test-imply-truthy = {
    expr = imply "yes" 42;
    expected = 42;
  };
  primitives-trivial.test-imply-falsy = {
    expr = imply null 42;
    expected = null;
  };
  primitives-trivial.test-imply-empty-list = {
    expr = imply [ ] 42;
    expected = null;
  };
  primitives-trivial.test-apply-auto-args = {
    expr = applyAutoArgs ({ x, y }: x + y) {
      x = 1;
      y = 2;
      z = 3;
    };
    expected = 3;
  };
  primitives-trivial.test-apply-args = {
    expr =
      applyArgs
        (
          a: b: c:
          a + b + c
        )
        [
          1
          2
          3
        ];
    expected = 6;
  };
}
