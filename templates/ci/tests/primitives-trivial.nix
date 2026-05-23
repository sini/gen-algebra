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
  primitives-trivial.test-nand-tt = {
    expr = nand true true;
    expected = false;
  };
  primitives-trivial.test-nand-tf = {
    expr = nand true false;
    expected = true;
  };
  primitives-trivial.test-nor-ff = {
    expr = nor false false;
    expected = true;
  };
  primitives-trivial.test-nor-tf = {
    expr = nor true false;
    expected = false;
  };
  primitives-trivial.test-xnor-same = {
    expr = xnor true true;
    expected = true;
  };
  primitives-trivial.test-xnor-diff = {
    expr = xnor true false;
    expected = false;
  };
  primitives-trivial.test-imply-default-falsy = {
    expr = implyDefault false "fallback" 42;
    expected = "fallback";
  };
  primitives-trivial.test-imply-default-truthy = {
    expr = implyDefault true "fallback" 42;
    expected = 42;
  };
  primitives-trivial.test-imply-empty-string = {
    expr = imply "" 42;
    expected = null;
  };
  primitives-trivial.test-imply-empty-attrs = {
    expr = imply { } 42;
    expected = null;
  };
  primitives-trivial.test-imply-zero = {
    expr = imply 0 42;
    expected = null;
  };
}
