{ lib, genAlgebra, ... }:
let
  R = genAlgebra.record;

  a = R.fromAttrs {
    x = 1;
    y = 2;
  };
  b = R.fromAttrs {
    x = 10;
    z = 3;
  };
  # `combine` takes one record (P2, R7 (b)); this binds it positionally for the nested cells.
  cmb = left: right: R.combine { inherit left right; };
in
{
  # R7 (b): two operands of one sort are one record, and its fields are the door's formals.
  flake.tests.rec-composition.test-combine-takes-one-record = {
    expr = builtins.functionArgs R.combine;
    expected = {
      left = false;
      right = false;
    };
  };

  flake.tests.rec-composition.test-combine-left-wins = {
    expr = R.select "x" (
      R.combine {
        left = a;
        right = b;
      }
    );
    expected = 1;
  };

  flake.tests.rec-composition.test-combine-preserves-right = {
    expr = R.has "z" (cmb a b);
    expected = true;
  };

  flake.tests.rec-composition.test-combine-stacks = {
    expr = R.depth "x" (cmb a b);
    expected = 2;
  };

  flake.tests.rec-composition.test-combine-left-order-first = {
    expr = R.labels (cmb a b);
    expected = [
      "x"
      "y"
      "z"
    ];
  };

  flake.tests.rec-composition.test-combine-associative = {
    expr =
      let
        c = R.fromAttrs {
          x = 100;
          w = 4;
        };
        left = cmb (cmb a b) c;
        right = cmb a (cmb b c);
      in
      R.emit left == R.emit right;
    expected = true;
  };

  flake.tests.rec-composition.test-combine-associative-depth = {
    expr =
      let
        c = R.fromAttrs {
          x = 100;
          w = 4;
        };
        left = cmb (cmb a b) c;
        right = cmb a (cmb b c);
      in
      R.depth "x" left == R.depth "x" right;
    expected = true;
  };

  flake.tests.rec-composition.test-mixin-smalltalk-delta-wins = {
    expr =
      let
        parent = R.fromAttrs { display = "name"; };
        delta =
          p:
          R.fromAttrs {
            display = "${R.select "display" p}, degree";
          };
      in
      R.select "display" (R.mixin delta parent);
    expected = "name, degree";
  };

  flake.tests.rec-composition.test-mixin-preserves-parent-fields = {
    expr =
      let
        parent = R.fromAttrs {
          display = "name";
          extra = true;
        };
        delta = _p: R.fromAttrs { display = "override"; };
      in
      R.has "extra" (R.mixin delta parent);
    expected = true;
  };

  flake.tests.rec-composition.test-mixinBeta-prefix-wins = {
    expr =
      let
        prefix =
          inner:
          R.fromAttrs {
            display = "prefix-${R.select "display" inner}";
          };
        suffix = R.fromAttrs { display = "suffix"; };
      in
      R.select "display" (R.mixinBeta prefix suffix);
    expected = "prefix-suffix";
  };

  flake.tests.rec-composition.test-compose-associative = {
    expr =
      let
        m1 = R.extend "a" 1;
        m2 = R.extend "b" 2;
        m3 = R.extend "c" 3;
        left = R.compose (R.compose m1 m2) m3;
        right = R.compose m1 (R.compose m2 m3);
        base = R.empty;
      in
      R.emit (left base) == R.emit (right base);
    expected = true;
  };

  flake.tests.rec-composition.test-extend-restrict-identity = {
    expr =
      let
        r = R.fromAttrs {
          x = 1;
          y = 2;
        };
      in
      R.restrict "z" (R.extend "z" 3 r) == r;
    expected = true;
  };

  flake.tests.rec-composition.test-select-after-extend = {
    expr = R.select "x" (R.extend "x" 42 R.empty);
    expected = 42;
  };

  flake.tests.rec-composition.test-combine-associative-order = {
    expr =
      let
        c = R.fromAttrs {
          x = 100;
          w = 4;
        };
        left = R.labels (cmb (cmb a b) c);
        right = R.labels (cmb a (cmb b c));
      in
      left == right;
    expected = true;
  };
}
