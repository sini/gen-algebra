{ lib, genLib, ... }:
let
  R = genLib.pure.record;

  a = R.fromAttrs { x = 1; y = 2; };
  b = R.fromAttrs { x = 10; z = 3; };
in
{
  rec-composition.test-combine-left-wins = {
    expr = R.select (R.combine a b) "x";
    expected = 1;
  };

  rec-composition.test-combine-preserves-right = {
    expr = R.has (R.combine a b) "z";
    expected = true;
  };

  rec-composition.test-combine-stacks = {
    expr = R.depth (R.combine a b) "x";
    expected = 2;
  };

  rec-composition.test-combine-left-order-first = {
    expr = R.labels (R.combine a b);
    expected = [ "x" "y" "z" ];
  };

  rec-composition.test-combine-associative = {
    expr =
      let
        c = R.fromAttrs { x = 100; w = 4; };
        left = R.combine (R.combine a b) c;
        right = R.combine a (R.combine b c);
      in
      R.emit left == R.emit right;
    expected = true;
  };

  rec-composition.test-combine-associative-depth = {
    expr =
      let
        c = R.fromAttrs { x = 100; w = 4; };
        left = R.combine (R.combine a b) c;
        right = R.combine a (R.combine b c);
      in
      R.depth left "x" == R.depth right "x";
    expected = true;
  };

  rec-composition.test-mixin-smalltalk-delta-wins = {
    expr =
      let
        parent = R.fromAttrs { display = "name"; };
        delta = p: R.fromAttrs {
          display = "${R.select p "display"}, degree";
        };
      in
      R.select (R.mixin delta parent) "display";
    expected = "name, degree";
  };

  rec-composition.test-mixin-preserves-parent-fields = {
    expr =
      let
        parent = R.fromAttrs { display = "name"; extra = true; };
        delta = _p: R.fromAttrs { display = "override"; };
      in
      R.has (R.mixin delta parent) "extra";
    expected = true;
  };

  rec-composition.test-mixinBeta-prefix-wins = {
    expr =
      let
        prefix = inner: R.fromAttrs {
          display = "prefix-${R.select inner "display"}";
        };
        suffix = R.fromAttrs { display = "suffix"; };
      in
      R.select (R.mixinBeta prefix suffix) "display";
    expected = "prefix-suffix";
  };

  rec-composition.test-compose-associative = {
    expr =
      let
        m1 = p: R.extend p "a" 1;
        m2 = p: R.extend p "b" 2;
        m3 = p: R.extend p "c" 3;
        left = R.compose (R.compose m1 m2) m3;
        right = R.compose m1 (R.compose m2 m3);
        base = R.empty;
      in
      R.emit (left base) == R.emit (right base);
    expected = true;
  };

  rec-composition.test-extend-restrict-identity = {
    expr =
      let
        r = R.fromAttrs { x = 1; y = 2; };
      in
      R.restrict (R.extend r "z" 3) "z" == r;
    expected = true;
  };

  rec-composition.test-select-after-extend = {
    expr = R.select (R.extend R.empty "x" 42) "x";
    expected = 42;
  };

  rec-composition.test-combine-associative-order = {
    expr =
      let
        c = R.fromAttrs { x = 100; w = 4; };
        left = R.labels (R.combine (R.combine a b) c);
        right = R.labels (R.combine a (R.combine b c));
      in
      left == right;
    expected = true;
  };
}
