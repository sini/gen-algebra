{ lib, genLib, ... }:
let
  inherit (genLib.pure.primitives.lists)
    indexOf
    sublist
    split
    lsplit
    rsplit
    lpad
    rpad
    replicate
    reverse
    range
    ;
in
{
  primitives-lists.test-index-of-found = {
    expr = indexOf 3 [
      1
      2
      3
      4
    ];
    expected = 2;
  };
  primitives-lists.test-index-of-not-found = {
    expr = indexOf 9 [
      1
      2
      3
    ];
    expected = null;
  };
  primitives-lists.test-sublist = {
    expr = sublist 1 3 [
      0
      1
      2
      3
      4
    ];
    expected = [
      1
      2
    ];
  };
  primitives-lists.test-split = {
    expr = split 0 [
      1
      2
      0
      3
      4
      0
      5
    ];
    expected = [
      [
        1
        2
      ]
      [
        3
        4
      ]
      [ 5 ]
    ];
  };
  primitives-lists.test-lsplit = {
    expr = lsplit 0 [
      1
      2
      0
      3
      4
    ];
    expected = {
      l = [
        1
        2
      ];
      r = [
        3
        4
      ];
    };
  };
  primitives-lists.test-rsplit = {
    expr = rsplit 0 [
      1
      0
      2
      0
      3
    ];
    expected = {
      l = [
        1
        0
        2
      ];
      r = [ 3 ];
    };
  };
  primitives-lists.test-lpad = {
    expr = lpad 0 5 [
      1
      2
      3
    ];
    expected = [
      0
      0
      1
      2
      3
    ];
  };
  primitives-lists.test-rpad = {
    expr = rpad 0 5 [
      1
      2
    ];
    expected = [
      1
      2
      0
      0
      0
    ];
  };
  primitives-lists.test-replicate = {
    expr = replicate 3 "x";
    expected = [
      "x"
      "x"
      "x"
    ];
  };
  primitives-lists.test-reverse = {
    expr = reverse [
      1
      2
      3
    ];
    expected = [
      3
      2
      1
    ];
  };
  primitives-lists.test-range = {
    expr = range 2 5;
    expected = [
      2
      3
      4
      5
    ];
  };
}
