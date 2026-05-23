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
    last
    imap0
    indicesOf
    indicesOfPred
    indexOfDefault
    lastIndexOf
    elemAtDefault
    removeElems
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
  primitives-lists.test-last = {
    expr = last [ 1 2 3 ];
    expected = 3;
  };
  primitives-lists.test-last-singleton = {
    expr = last [ 42 ];
    expected = 42;
  };
  primitives-lists.test-imap0 = {
    expr = imap0 (i: v: i + v) [ 10 20 30 ];
    expected = [ 10 21 32 ];
  };
  primitives-lists.test-indices-of = {
    expr = indicesOf 1 [ 1 2 1 3 1 ];
    expected = [ 0 2 4 ];
  };
  primitives-lists.test-indices-of-none = {
    expr = indicesOf 9 [ 1 2 3 ];
    expected = [ ];
  };
  primitives-lists.test-indices-of-pred = {
    expr = indicesOfPred (x: x > 2) [ 1 3 2 4 ];
    expected = [ 1 3 ];
  };
  primitives-lists.test-index-of-default = {
    expr = indexOfDefault (-1) 9 [ 1 2 3 ];
    expected = (-1);
  };
  primitives-lists.test-last-index-of = {
    expr = lastIndexOf 1 [ 1 2 1 3 ];
    expected = 2;
  };
  primitives-lists.test-last-index-of-none = {
    expr = lastIndexOf 9 [ 1 2 3 ];
    expected = null;
  };
  primitives-lists.test-elem-at-default-valid = {
    expr = elemAtDefault 0 1 [ 10 20 30 ];
    expected = 20;
  };
  primitives-lists.test-elem-at-default-oob = {
    expr = elemAtDefault 0 5 [ 10 20 ];
    expected = 0;
  };
  primitives-lists.test-remove-elems = {
    expr = removeElems [ 2 4 ] [ 1 2 3 4 5 ];
    expected = [ 1 3 5 ];
  };
  primitives-lists.test-split-no-match = {
    expr = split 9 [ 1 2 3 ];
    expected = [ [ 1 2 3 ] ];
  };
  primitives-lists.test-lsplit-not-found = {
    expr = lsplit 9 [ 1 2 3 ];
    expected = null;
  };
  primitives-lists.test-rsplit-not-found = {
    expr = rsplit 9 [ 1 2 3 ];
    expected = null;
  };
  primitives-lists.test-lpad-noop = {
    expr = lpad 0 2 [ 1 2 3 ];
    expected = [ 1 2 3 ];
  };
  primitives-lists.test-rpad-noop = {
    expr = rpad 0 2 [ 1 2 3 ];
    expected = [ 1 2 3 ];
  };
  primitives-lists.test-replicate-zero = {
    expr = replicate 0 "x";
    expected = [ ];
  };
  primitives-lists.test-reverse-empty = {
    expr = reverse [ ];
    expected = [ ];
  };
}
