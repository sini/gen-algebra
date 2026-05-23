# 64-bit unsigned modular arithmetic on Nix's signed 64-bit integers.
let
  bits = import ./bits.nix;
  inherit (bits) bitShiftLeft bitShiftRight;
  inherit (builtins) bitAnd bitOr bitXor;

  mask32 = 4294967295; # 0xFFFFFFFF
  mask16 = 65535; # 0xFFFF

  lo32 = x: bitAnd x mask32;
  hi32 = x: bitAnd (bitShiftRight 32 x) mask32;
  lo16 = x: bitAnd x mask16;
  hi16 = x: bitAnd (bitShiftRight 16 x) mask16;

  wrapAdd =
    a: b:
    let
      aL = lo32 a;
      aH = hi32 a;
      bL = lo32 b;
      bH = hi32 b;
      sumL = aL + bL;
      carry = bitShiftRight 32 sumL;
      resultL = lo32 sumL;
      resultH = lo32 (aH + bH + carry);
    in
    bitOr (bitShiftLeft 32 resultH) resultL;

  wrapNeg = x: wrapAdd (bitXor x (-1)) 1;

  wrapSub = a: b: wrapAdd a (wrapNeg b);

  # 16-bit schoolbook multiplication: split each operand into four 16-bit
  # quarters and accumulate column sums with carry.  Every intermediate
  # value stays well below 2^63 (max column sum ≈ 2^34).
  wrapMul =
    a: b:
    let
      a0 = lo16 a;
      a1 = hi16 a;
      a2 = lo16 (bitShiftRight 32 a);
      a3 = hi16 (bitShiftRight 32 a);

      b0 = lo16 b;
      b1 = hi16 b;
      b2 = lo16 (bitShiftRight 32 b);
      b3 = hi16 (bitShiftRight 32 b);

      # Column 0 (bit 0)
      c0 = a0 * b0;
      r0 = lo16 c0;
      carry0 = bitShiftRight 16 c0;

      # Column 1 (bit 16)
      c1 = a0 * b1 + a1 * b0 + carry0;
      r1 = lo16 c1;
      carry1 = bitShiftRight 16 c1;

      # Column 2 (bit 32)
      c2 = a0 * b2 + a1 * b1 + a2 * b0 + carry1;
      r2 = lo16 c2;
      carry2 = bitShiftRight 16 c2;

      # Column 3 (bit 48) — higher columns discarded mod 2^64
      c3 = a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0 + carry2;
      r3 = lo16 c3;
    in
    bitOr (bitOr r0 (bitShiftLeft 16 r1)) (bitOr (bitShiftLeft 32 r2) (bitShiftLeft 48 r3));

  rotl64 = x: n: bitOr (bitShiftLeft n x) (bitShiftRight (64 - n) x);
in
{
  inherit
    wrapAdd
    wrapSub
    wrapMul
    wrapNeg
    rotl64
    ;
}
