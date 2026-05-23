# Boolean operations and function application utilities — builtins only.
let
  not = a: !a;
  nand = a: b: !(a && b);
  nor = a: b: !(a || b);
  xor = a: b: (a || b) && !(a && b);
  xnor = a: b: !(a || b) || (a && b);

  # Truthiness-based conditional: null, false, {}, [], "", 0 are falsy.
  implyDefault =
    cond: default: value:
    if (cond == null) || cond == false || cond == { } || cond == [ ] || cond == "" || cond == 0 then
      default
    else
      value;

  imply = cond: value: implyDefault cond null value;

  applyArgs = builtins.foldl' (fn': fn');

  applyAutoArgs =
    fn: attrs:
    let
      fnArgs = builtins.functionArgs fn;
      autoArgs = builtins.intersectAttrs fnArgs attrs;
    in
    fn autoArgs;
in
{
  inherit
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
}
