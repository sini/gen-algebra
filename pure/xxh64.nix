# xxh64 hash algorithm — pure Nix implementation.
# Follows the official xxHash specification (seed=0 default).
# Uses constant-specialized multiplies and rotations for performance.
let
  primitives = import ./primitives;
  inherit (primitives.wrapping)
    wrapAdd
    wrapSub
    shr32
    mask32
    rotl1
    rotl7
    rotl11
    rotl12
    rotl18
    rotl23
    rotl27
    rotl31
    ;
  inherit (primitives.bytes) stringToBytes readLE64 readLE32;
  inherit (primitives.radix) intToHexPadded;
  inherit (builtins)
    bitAnd
    bitOr
    bitXor
    elemAt
    length
    ;

  intMax = 9223372036854775807;
  intMin = -9223372036854775807 - 1;
  mask16 = 65535;

  # Inlined right-shifts for avalanche (29, 33) and hex output (32 via shr32)
  shr29 = x: if x < 0 then (bitAnd x intMax) / 536870912 + 17179869184 else x / 536870912;
  shr33 = x: if x < 0 then (bitAnd x intMax) / 8589934592 + 1073741824 else x / 8589934592;

  # Inlined left-shifts for multiply assembly
  shl32 = x:
    let
      full = bitAnd x 4294967295;
      sb = 2147483648;
      hs = bitAnd full sb != 0;
      safe = bitAnd full (sb - 1);
      r = safe * 4294967296;
    in
    if hs then r + intMin else r;
  shl48 = x:
    let
      full = bitAnd x mask16;
      sb = 32768;
      hs = bitAnd full sb != 0;
      safe = bitAnd full (sb - 1);
      r = safe * 281474976710656;
    in
    if hs then r + intMin else r;

  # Decompose input x into 16-bit quarters (shared by all mulPN functions)
  lo16 = x: bitAnd x mask16;
  hi16 = x: bitAnd (if x < 0 then (bitAnd x intMax) / 65536 + 140737488355328 else x / 65536) mask16;

  # Constant-specialized multiply: pre-split prime into 16-bit quarters so only
  # the variable operand needs runtime decomposition (saves ~8 ops per call).
  mkMulConst =
    b0: b1: b2: b3: a:
    let
      aHi = shr32 a;
      a0 = lo16 a;
      a1 = hi16 a;
      a2 = lo16 aHi;
      a3 = hi16 aHi;
      c0 = a0 * b0;
      r0 = lo16 c0;
      carry0 = c0 / 65536;
      c1 = a0 * b1 + a1 * b0 + carry0;
      r1 = lo16 c1;
      carry1 = c1 / 65536;
      c2 = a0 * b2 + a1 * b1 + a2 * b0 + carry1;
      r2 = lo16 c2;
      carry2 = c2 / 65536;
      c3 = a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0 + carry2;
      r3 = lo16 c3;
    in
    bitOr (bitOr r0 (r1 * 65536)) (bitOr (shl32 r2) (shl48 r3));

  # xxh64 primes — unsigned hex values stored as Nix signed 64-bit integers.
  # Spec: https://github.com/Cyan4973/xxHash/blob/dev/doc/xxhash_spec.md
  # Each prime is pre-split into 16-bit quarters for the specialized multiply.
  #                                          q3     q2     q1     q0
  mulP1 = mkMulConst 51847 34283 31153 40503; # P1 = 0x9E3779B185EBCA87
  mulP2 = mkMulConst 60239 10196 44605 49842; # P2 = 0xC2B2AE3D27D4EB4F
  mulP3 = mkMulConst 31225 40503 26545 5718;  # P3 = 0x165667B19E3779F9
  # Primes used as additive constants (not multiplied on hot path)
  PRIME64_1 = -7046029288634856825;  # 0x9E3779B185EBCA87
  PRIME64_2 = -4417276706812531889;  # 0xC2B2AE3D27D4EB4F
  PRIME64_3 = 1609587929392839161;   # 0x165667B19E3779F9
  PRIME64_4 = -8796714831421723037;  # 0x85EBCA77C2B2AE63
  PRIME64_5 = 2870177450012600261;   # 0x27D4EB2F165667C5

  # General wrapMul still needed for non-constant multiplies (e.g., consume1 byte*P5)
  inherit (primitives.wrapping) wrapMul;

  round = acc: lane: mulP1 (rotl31 (wrapAdd acc (mulP2 lane)));

  mergeAccumulator = acc: accN: wrapAdd (mulP1 (bitXor acc (round 0 accN))) PRIME64_4;

  avalanche =
    acc:
    let
      s1 = bitXor acc (shr33 acc);
      s2 = mulP2 s1;
      s3 = bitXor s2 (shr29 s2);
      s4 = mulP3 s3;
    in
    bitXor s4 (shr32 s4);

  # Process remaining bytes after 32-byte stripes
  consumeRemaining =
    bytes: offset: len: acc:
    let
      # Process 8-byte chunks
      consume8 =
        off: a:
        if off + 8 <= len then
          let
            k1 = readLE64 bytes off;
            a' = bitXor a (round 0 k1);
            a'' = wrapAdd (mulP1 (rotl27 a')) PRIME64_4;
          in
          consume8 (off + 8) a''
        else
          { inherit a off; };

      after8 = consume8 offset acc;

      # Process 4-byte chunk
      after4 =
        if after8.off + 4 <= len then
          let
            k1 = readLE32 bytes after8.off;
            a' = bitXor after8.a (mulP1 k1);
            a'' = wrapAdd (mulP2 (rotl23 a')) PRIME64_3;
          in
          {
            a = a'';
            off = after8.off + 4;
          }
        else
          after8;

      # Process remaining single bytes — uses general wrapMul since the byte value varies
      consume1 =
        off: a:
        if off < len then
          let
            b = elemAt bytes off;
            a' = bitXor a (wrapMul b PRIME64_5);
            a'' = mulP1 (rotl11 a');
          in
          consume1 (off + 1) a''
        else
          a;
    in
    consume1 after4.off after4.a;

  # Process 32-byte stripes via fold
  processStripes =
    bytes: numStripes: initAcc1: initAcc2: initAcc3: initAcc4:
    let
      step =
        state: i:
        let
          off = i * 32;
        in
        {
          acc1 = round state.acc1 (readLE64 bytes off);
          acc2 = round state.acc2 (readLE64 bytes (off + 8));
          acc3 = round state.acc3 (readLE64 bytes (off + 16));
          acc4 = round state.acc4 (readLE64 bytes (off + 24));
        };
    in
    builtins.foldl' step {
      acc1 = initAcc1;
      acc2 = initAcc2;
      acc3 = initAcc3;
      acc4 = initAcc4;
    } (builtins.genList (i: i) numStripes);

  # Split 64-bit value into two 32-bit halves for hex conversion,
  # since intToHex only handles non-negative integers.
  toHex16 =
    n:
    let
      lo = bitAnd n mask32;
      hi = bitAnd (shr32 n) mask32;
    in
    intToHexPadded 8 hi + intToHexPadded 8 lo;

  xxh64Impl =
    seed: str:
    let
      bytes = stringToBytes str;
      len = length bytes;

      acc =
        if len < 32 then
          wrapAdd (wrapAdd seed PRIME64_5) len
        else
          let
            acc1init = wrapAdd (wrapAdd seed PRIME64_1) PRIME64_2;
            acc2init = wrapAdd seed PRIME64_2;
            acc3init = seed;
            acc4init = wrapSub seed PRIME64_1;
            numStripes = len / 32;
            s = processStripes bytes numStripes acc1init acc2init acc3init acc4init;
            converged = wrapAdd (wrapAdd (rotl1 s.acc1) (rotl7 s.acc2)) (
              wrapAdd (rotl12 s.acc3) (rotl18 s.acc4)
            );
            merged = mergeAccumulator (mergeAccumulator (mergeAccumulator (mergeAccumulator converged s.acc1) s.acc2) s.acc3) s.acc4;
          in
          wrapAdd merged len;

      remaining = consumeRemaining bytes (len / 32 * 32) len acc;
    in
    toHex16 (avalanche remaining);
in
{
  xxh64 = xxh64Impl 0;
  xxh64WithSeed = xxh64Impl;
}
