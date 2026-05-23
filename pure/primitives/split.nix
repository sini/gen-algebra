# Split {hi, lo} 64-bit arithmetic — optimized for xxh64.
# Both hi and lo are always non-negative 0..2^32-1, eliminating sign-bit
# handling from all intermediate operations. Only boundary conversions
# (toSplit, toHex16) deal with signed integers.
let
  inherit (builtins)
    bitAnd
    bitOr
    bitXor
    elemAt
    foldl'
    ;

  mask32 = 4294967295;
  mask16 = 65535;
  intMax = 9223372036854775807;

  splitAdd =
    a: b:
    let
      sumLo = a.lo + b.lo;
      carry = sumLo / 4294967296;
    in
    {
      lo = bitAnd sumLo mask32;
      hi = bitAnd (a.hi + b.hi + carry) mask32;
    };

  splitSub =
    a: b:
    let
      diffLo = a.lo - b.lo;
      borrow = if diffLo < 0 then 1 else 0;
    in
    {
      lo = bitAnd diffLo mask32;
      hi = bitAnd (a.hi - b.hi - borrow) mask32;
    };

  splitXor = a: b: {
    lo = bitXor a.lo b.lo;
    hi = bitXor a.hi b.hi;
  };

  # Precomputed rotation by N bits. Halves are non-negative so shifts are
  # plain multiply/divide with no sign-bit conditionals.
  mkSplitRotl =
    n:
    if n < 32 then
      let
        mult = foldl' (a: _: a * 2) 1 (builtins.genList (_: 0) n);
        div = foldl' (a: _: a * 2) 1 (builtins.genList (_: 0) (32 - n));
      in
      x: {
        lo = bitAnd (bitOr (x.lo * mult) (x.hi / div)) mask32;
        hi = bitAnd (bitOr (x.hi * mult) (x.lo / div)) mask32;
      }
    else
      let
        n2 = n - 32;
        mult = foldl' (a: _: a * 2) 1 (builtins.genList (_: 0) n2);
        div = foldl' (a: _: a * 2) 1 (builtins.genList (_: 0) (32 - n2));
      in
      x: {
        lo = bitAnd (bitOr (x.hi * mult) (x.lo / div)) mask32;
        hi = bitAnd (bitOr (x.lo * mult) (x.hi / div)) mask32;
      };

  rotl1 = mkSplitRotl 1;
  rotl7 = mkSplitRotl 7;
  rotl11 = mkSplitRotl 11;
  rotl12 = mkSplitRotl 12;
  rotl18 = mkSplitRotl 18;
  rotl23 = mkSplitRotl 23;
  rotl27 = mkSplitRotl 27;
  rotl31 = mkSplitRotl 31;

  # Multiply split value by a constant whose 16-bit quarters are pre-split.
  # All intermediates fit signed 64-bit: max quarter product is 2^16 * 2^16 = 2^32,
  # max column sum ~ 4 * 2^32 + 2^16 carry < 2^35.
  splitMulConst =
    b0: b1: b2: b3: a:
    let
      a0 = bitAnd a.lo mask16;
      a1 = a.lo / 65536;
      a2 = bitAnd a.hi mask16;
      a3 = a.hi / 65536;
      c0 = a0 * b0;
      r0 = bitAnd c0 mask16;
      carry0 = c0 / 65536;
      c1 = a0 * b1 + a1 * b0 + carry0;
      r1 = bitAnd c1 mask16;
      carry1 = c1 / 65536;
      c2 = a0 * b2 + a1 * b1 + a2 * b0 + carry1;
      r2 = bitAnd c2 mask16;
      carry2 = c2 / 65536;
      c3 = a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0 + carry2;
      r3 = bitAnd c3 mask16;
    in
    {
      lo = bitOr r0 (r1 * 65536);
      hi = bitOr r2 (r3 * 65536);
    };

  # Pre-split prime multiplies (16-bit quarters of each prime constant)
  mulP1 = splitMulConst 51847 34283 31153 40503;
  mulP2 = splitMulConst 60239 10196 44605 49842;
  mulP3 = splitMulConst 31225 40503 26545 5718;

  # Small integer * split value (for consume1 byte path)
  mulByByte =
    byte: p:
    let
      prodLo = byte * p.lo;
      prodHi = byte * p.hi;
    in
    {
      lo = bitAnd prodLo mask32;
      hi = bitAnd (prodHi + prodLo / 4294967296) mask32;
    };

  # Right-shifts in split representation
  shr29 = x: {
    lo = bitAnd (bitOr (x.lo / 536870912) (x.hi * 8)) mask32;
    hi = x.hi / 536870912;
  };
  shr32 = x: {
    lo = x.hi;
    hi = 0;
  };
  shr33 = x: {
    lo = x.hi / 2;
    hi = 0;
  };

  # Signed 64-bit integer to split representation (boundary conversion only)
  toSplit = n: {
    lo = bitAnd n mask32;
    hi = bitAnd (if n < 0 then (bitAnd n intMax) / 4294967296 + 2147483648 else n / 4294967296) mask32;
  };
in
{
  inherit
    splitAdd
    splitSub
    splitXor
    mkSplitRotl
    rotl1
    rotl7
    rotl11
    rotl12
    rotl18
    rotl23
    rotl27
    rotl31
    splitMulConst
    mulP1
    mulP2
    mulP3
    mulByByte
    shr29
    shr32
    shr33
    toSplit
    ;
}
