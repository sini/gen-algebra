# xxh64 hash algorithm — pure Nix implementation.
# Follows the official xxHash specification (seed=0 default).
let
  primitives = import ./primitives;
  inherit (primitives.bits) bitShiftLeft bitShiftRight;
  inherit (primitives.wrapping)
    wrapAdd
    wrapSub
    wrapMul
    rotl64
    ;
  inherit (primitives.bytes) stringToBytes readLE64 readLE32;
  inherit (primitives.radix) intToHex intToHexPadded;
  inherit (builtins)
    bitAnd
    bitOr
    bitXor
    elemAt
    length
    ;

  # xxh64 primes — unsigned hex values stored as Nix signed 64-bit integers.
  # Spec: https://github.com/Cyan4973/xxHash/blob/dev/doc/xxhash_spec.md
  PRIME64_1 = -7046029288634856825;  # 0x9E3779B185EBCA87
  PRIME64_2 = -4417276706812531889;  # 0xC2B2AE3D27D4EB4F
  PRIME64_3 = 1609587929392839161;   # 0x165667B19E3779F9
  PRIME64_4 = -8796714831421723037;  # 0x85EBCA77C2B2AE63
  PRIME64_5 = 2870177450012600261;   # 0x27D4EB2F165667C5

  round = acc: lane: wrapMul (rotl64 (wrapAdd acc (wrapMul lane PRIME64_2)) 31) PRIME64_1;

  mergeAccumulator = acc: accN: wrapAdd (wrapMul (bitXor acc (round 0 accN)) PRIME64_1) PRIME64_4;

  avalanche =
    acc:
    let
      s1 = bitXor acc (bitShiftRight 33 acc);
      s2 = wrapMul s1 PRIME64_2;
      s3 = bitXor s2 (bitShiftRight 29 s2);
      s4 = wrapMul s3 PRIME64_3;
    in
    bitXor s4 (bitShiftRight 32 s4);

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
            a'' = wrapAdd (wrapMul (rotl64 a' 27) PRIME64_1) PRIME64_4;
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
            a' = bitXor after8.a (wrapMul k1 PRIME64_1);
            a'' = wrapAdd (wrapMul (rotl64 a' 23) PRIME64_2) PRIME64_3;
          in
          {
            a = a'';
            off = after8.off + 4;
          }
        else
          after8;

      # Process remaining single bytes
      consume1 =
        off: a:
        if off < len then
          let
            b = elemAt bytes off;
            a' = bitXor a (wrapMul b PRIME64_5);
            a'' = wrapMul (rotl64 a' 11) PRIME64_1;
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

  mask32 = 4294967295;

  # Split 64-bit value into two 32-bit halves for hex conversion,
  # since intToHex only handles non-negative integers.
  toHex16 =
    n:
    let
      lo = bitAnd n mask32;
      hi = bitAnd (bitShiftRight 32 n) mask32;
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
            converged = wrapAdd (wrapAdd (rotl64 s.acc1 1) (rotl64 s.acc2 7)) (
              wrapAdd (rotl64 s.acc3 12) (rotl64 s.acc4 18)
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
