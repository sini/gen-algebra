# Numeric primitives — zero dependencies, builtins only.
let
  # Requires non-negative exponent (genList with negative length is []).
  pow = base: exp: builtins.foldl' builtins.mul 1 (builtins.genList (_: base) exp);

  powi = base: exp: builtins.floor (pow base exp);

  abs =
    n:
    if n == (-9223372036854775807 - 1) then
      builtins.throw "gen: abs: INT_MIN has no positive representation"
    else if n < 0 then
      -n
    else
      n;

  # C/truncation semantics: remainder sign follows dividend.
  mod = a: b: a - (a / b) * b;

  mantissa = n: n - (builtins.floor n);

  round =
    decimals: n:
    let
      shift = pow 10.0 decimals;
      shifted = n * shift;
      roundFn = if mantissa shifted >= 0.5 then builtins.ceil else builtins.floor;
    in
    (roundFn shifted) / shift;
in
{
  inherit
    pow
    powi
    abs
    mod
    mantissa
    round
    ;
}
