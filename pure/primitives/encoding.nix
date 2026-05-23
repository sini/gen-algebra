# Binary encoding/decoding — builtins only.
# All functions use MSB-first (big-endian) bit ordering:
# encodeBinary 5 → [1 0 1], where index 0 is the most significant bit.
let
  math = import ./math.nix;
  lists = import ./lists.nix;
  inherit (lists) reverse;

  encodeBinary =
    n:
    let
      go =
        num: acc:
        if num == 0 then
          acc
        else
          go (num / 2) ([ (num - (num / 2) * 2) ] ++ acc);
    in
    if n == 0 then [ 0 ] else go n [ ];

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
