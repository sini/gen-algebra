# 64-bit unsigned modular arithmetic on Nix's signed 64-bit integers.
# Performance-critical: all shift operations use inlined constants instead of
# the general bitShiftLeft/bitShiftRight to avoid elemAt lookups.
let
  inherit (builtins) bitAnd bitOr bitXor;

  mask32 = 4294967295; # 0xFFFFFFFF
  mask16 = 65535; # 0xFFFF
  intMax = 9223372036854775807; # 0x7FFFFFFFFFFFFFFF
  intMin = -9223372036854775807 - 1; # 0x8000000000000000

  lo32 = x: bitAnd x mask32;
  lo16 = x: bitAnd x mask16;

  # Inlined right-shift-by-N: integer division + sign-bit restoration.
  # For shift by N: divide by 2^N, add 2^(63-N) if negative.
  shr16 = x: if x < 0 then (bitAnd x intMax) / 65536 + 140737488355328 else x / 65536;
  shr32 = x: if x < 0 then (bitAnd x intMax) / 4294967296 + 2147483648 else x / 4294967296;

  hi16 = x: bitAnd (shr16 x) mask16;
  hi32 = x: bitAnd (shr32 x) mask32;

  # Inlined left-shift-by-N with safe overflow handling.
  # Strip the bit that will become the sign bit, multiply, then add intMin if it was set.
  shl16 =
    x:
    let
      full = bitAnd x 281474976710655; # low 48 bits
      signBit = 140737488355328; # 2^47 — becomes sign bit after <<16
      hasSign = bitAnd full signBit != 0;
      safe = bitAnd full (signBit - 1); # strip bit 47
      result = safe * 65536; # max (2^47-1)*2^16 = 2^63-2^16, safe
    in
    if hasSign then result + intMin else result;

  shl32 =
    x:
    let
      full = bitAnd x mask32; # low 32 bits
      signBit = 2147483648; # 2^31 — becomes sign bit after <<32
      hasSign = bitAnd full signBit != 0;
      safe = bitAnd full (signBit - 1); # strip bit 31
      result = safe * 4294967296; # max (2^31-1)*2^32 = 2^63-2^32, safe
    in
    if hasSign then result + intMin else result;

  shl48 =
    x:
    let
      full = bitAnd x mask16; # low 16 bits
      signBit = 32768; # 2^15 — becomes sign bit after <<48
      hasSign = bitAnd full signBit != 0;
      safe = bitAnd full (signBit - 1); # strip bit 15
      result = safe * 281474976710656; # max (2^15-1)*2^48 = 2^63-2^48, safe
    in
    if hasSign then result + intMin else result;

  wrapAdd =
    a: b:
    let
      aL = lo32 a;
      aH = hi32 a;
      bL = lo32 b;
      bH = hi32 b;
      sumL = aL + bL;
      carry = shr32 sumL;
      resultL = lo32 sumL;
      resultH = lo32 (aH + bH + carry);
    in
    bitOr (shl32 resultH) resultL;

  wrapNeg = x: wrapAdd (bitXor x (-1)) 1;

  wrapSub = a: b: wrapAdd a (wrapNeg b);

  # 16-bit schoolbook multiplication: split each operand into four 16-bit
  # quarters and accumulate column sums with carry. Every intermediate
  # value stays well below 2^63 (max column sum ~ 2^34).
  wrapMul =
    a: b:
    let
      aHi = shr32 a;
      a0 = lo16 a;
      a1 = hi16 a;
      a2 = lo16 aHi;
      a3 = hi16 aHi;

      bHi = shr32 b;
      b0 = lo16 b;
      b1 = hi16 b;
      b2 = lo16 bHi;
      b3 = hi16 bHi;

      # Column 0 (bit 0)
      c0 = a0 * b0;
      r0 = lo16 c0;
      carry0 = c0 / 65536;

      # Column 1 (bit 16)
      c1 = a0 * b1 + a1 * b0 + carry0;
      r1 = lo16 c1;
      carry1 = c1 / 65536;

      # Column 2 (bit 32)
      c2 = a0 * b2 + a1 * b1 + a2 * b0 + carry1;
      r2 = lo16 c2;
      carry2 = c2 / 65536;

      # Column 3 (bit 48) — higher columns discarded mod 2^64
      c3 = a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0 + carry2;
      r3 = lo16 c3;
    in
    bitOr (bitOr r0 (r1 * 65536)) (bitOr (shl32 r2) (shl48 r3));

  # General rotl64 for non-constant shift amounts (uses general bitShiftLeft/Right)
  bits = import ./bits.nix;
  rotl64 = x: n: bitOr (bits.bitShiftLeft n x) (bits.bitShiftRight (64 - n) x);

  # Pre-built constant rotations for xxh64.
  # Each precomputes masks/multipliers/divisors at definition time, so the
  # per-call cost is just: 2 bitAnd + 1 multiply + 1 divide + 2 bitOr.
  # mkRotl precomputes all constants for a given rotation amount.
  # Valid for n in 2..62 (n=1 handled separately due to pow2(63) overflow).
  mkRotl =
    n:
    let
      rn = 64 - n;
      pow2 = e: builtins.foldl' (a: _: a * 2) 1 (builtins.genList (_: 0) e);
      shlMask = pow2 (64 - n) - 1;
      shlSignBit = pow2 (63 - n);
      shlValMask = shlSignBit - 1;
      shlMult = pow2 n;
      shrDiv = pow2 rn;
      shrHighBit = pow2 (n - 1);
    in
    x:
    let
      masked = bitAnd x shlMask;
      hasSign = bitAnd masked shlSignBit != 0;
      safe = bitAnd masked shlValMask;
      left = let r = safe * shlMult; in if hasSign then r + intMin else r;
      right =
        if x < 0 then
          (bitAnd x intMax) / shrDiv + shrHighBit
        else
          x / shrDiv;
    in
    bitOr left right;

  # rotl1: hand-written because pow2(63) overflows in mkRotl
  # x << 1 = if bit 62 set then (x & (2^62-1)) * 2 + intMin else (x & intMax) * 2
  # x >> 63 = if x < 0 then 1 else 0
  rotl1 =
    x:
    let
      masked = bitAnd x intMax; # low 63 bits
      signBit = 4611686018427387904; # 2^62
      hasSign = bitAnd masked signBit != 0;
      safe = bitAnd masked (signBit - 1);
      left = let r = safe * 2; in if hasSign then r + intMin else r;
      right = if x < 0 then 1 else 0;
    in
    bitOr left right;
  rotl7 = mkRotl 7;
  rotl11 = mkRotl 11;
  rotl12 = mkRotl 12;
  rotl18 = mkRotl 18;
  rotl23 = mkRotl 23;
  rotl27 = mkRotl 27;
  rotl31 = mkRotl 31;
in
{
  inherit
    wrapAdd
    wrapSub
    wrapMul
    wrapNeg
    rotl64
    rotl1
    rotl7
    rotl11
    rotl12
    rotl18
    rotl23
    rotl27
    rotl31
    shr32
    mask32
    ;
}
