# Binary encoding/decoding — builtins only.
let
  math = import ./math.nix;

  reverse = xs: builtins.foldl' (acc: x: [ x ] ++ acc) [ ] xs;

  encodeBinary =
    n:
    let
      recurse = num: if num == 0 then [ ] else (recurse (num / 2)) ++ [ (num - (num / 2) * 2) ];
    in
    if n == 0 then [ 0 ] else recurse n;

  encodeBinaryBytes =
    n:
    let
      bits = encodeBinary n;
      numTrail = math.mod (builtins.length bits) 8;
      padding = builtins.genList (_: 0) (8 - numTrail);
    in
    if numTrail == 0 then bits else padding ++ bits;

  # Decode a big-endian list of bits into an integer.
  decodeBinary =
    bits:
    (builtins.foldl'
      (
        { int, place }:
        bit: {
          int = place * bit + int;
          place = place * 2;
        }
      )
      {
        int = 0;
        place = 1;
      }
      (reverse bits)
    ).int;
in
{
  inherit
    encodeBinary
    encodeBinaryBytes
    decodeBinary
    ;
}
