# xxh64 hash algorithm — pure Nix implementation.
# Follows the official xxHash specification (seed=0 default).
# Uses split {hi, lo} representation throughout the pipeline to avoid
# expensive sign-bit handling between operations.
let
  primitives = import ./primitives;
  inherit (primitives.split)
    splitAdd
    splitSub
    splitXor
    mulP1
    mulP2
    mulP3
    mulByByte
    rotl1
    rotl7
    rotl11
    rotl12
    rotl18
    rotl23
    rotl27
    rotl31
    shr29
    shr32
    shr33
    toSplit
    ;
  inherit (primitives.bytes) stringToBytes readLE64split readLE32split;
  inherit (primitives.radix) intToHexPadded;
  inherit (builtins) elemAt length;

  # Primes as split constants
  P1 = {
    lo = 2246822535;
    hi = 2654435761;
  };
  P2 = {
    lo = 668265295;
    hi = 3266489917;
  };
  P3 = {
    lo = 2654435833;
    hi = 374761393;
  };
  P4 = {
    lo = 3266489955;
    hi = 2246822519;
  };
  P5 = {
    lo = 374761413;
    hi = 668265263;
  };
  zero = {
    lo = 0;
    hi = 0;
  };

  round = acc: lane: mulP1 (rotl31 (splitAdd acc (mulP2 lane)));

  mergeAccumulator = acc: accN: splitAdd (mulP1 (splitXor acc (round zero accN))) P4;

  avalanche =
    acc:
    let
      s1 = splitXor acc (shr33 acc);
      s2 = mulP2 s1;
      s3 = splitXor s2 (shr29 s2);
      s4 = mulP3 s3;
    in
    splitXor s4 (shr32 s4);

  toHex16 = s: intToHexPadded 8 s.hi + intToHexPadded 8 s.lo;

  # Process remaining bytes after 32-byte stripes
  consumeRemaining =
    bytes: offset: len: acc:
    let
      consume8 =
        off: ac:
        if off + 8 <= len then
          let
            k = readLE64split bytes off;
            ac2 = splitXor ac (round zero k);
            ac3 = splitAdd (mulP1 (rotl27 ac2)) P4;
          in
          consume8 (off + 8) (builtins.deepSeq ac3 ac3)
        else
          { inherit ac off; };

      after8 = consume8 offset acc;

      after4 =
        if after8.off + 4 <= len then
          let
            k = readLE32split bytes after8.off;
            ac2 = splitXor after8.ac (mulP1 k);
            ac3 = splitAdd (mulP2 (rotl23 ac2)) P3;
          in
          {
            ac = ac3;
            off = after8.off + 4;
          }
        else
          after8;

      consume1 =
        off: ac:
        if off < len then
          let
            b = elemAt bytes off;
            ac2 = splitXor ac (mulByByte b P5);
            ac3 = mulP1 (rotl11 ac2);
          in
          consume1 (off + 1) (builtins.deepSeq ac3 ac3)
        else
          ac;
    in
    consume1 after4.off after4.ac;

  # Process 32-byte stripes via fold.
  # deepSeq at fold boundary prevents thunk chain buildup across stripes
  # (same principle as Haskell's BangPatterns on accumulator fields).
  processStripes =
    bytes: numStripes: initAcc1: initAcc2: initAcc3: initAcc4:
    builtins.foldl'
      (
        state: i:
        let
          off = i * 32;
          result = {
            acc1 = round state.acc1 (readLE64split bytes off);
            acc2 = round state.acc2 (readLE64split bytes (off + 8));
            acc3 = round state.acc3 (readLE64split bytes (off + 16));
            acc4 = round state.acc4 (readLE64split bytes (off + 24));
          };
        in
        builtins.deepSeq result result
      )
      {
        acc1 = initAcc1;
        acc2 = initAcc2;
        acc3 = initAcc3;
        acc4 = initAcc4;
      }
      (builtins.genList (i: i) numStripes);

  xxh64Impl =
    seed: str:
    let
      bytes = stringToBytes str;
      len = length bytes;
      seedSplit = toSplit seed;

      acc =
        if len < 32 then
          splitAdd (splitAdd seedSplit P5) (toSplit len)
        else
          let
            acc1init = splitAdd (splitAdd seedSplit P1) P2;
            acc2init = splitAdd seedSplit P2;
            acc3init = seedSplit;
            acc4init = splitSub seedSplit P1;
            numStripes = len / 32;
            s = processStripes bytes numStripes acc1init acc2init acc3init acc4init;
            converged = splitAdd (splitAdd (rotl1 s.acc1) (rotl7 s.acc2)) (
              splitAdd (rotl12 s.acc3) (rotl18 s.acc4)
            );
            merged = mergeAccumulator (mergeAccumulator (mergeAccumulator (mergeAccumulator converged s.acc1) s.acc2) s.acc3) s.acc4;
          in
          splitAdd merged (toSplit len);

      remaining = consumeRemaining bytes (len / 32 * 32) len acc;
    in
    toHex16 (avalanche remaining);
in
{
  xxh64 = xxh64Impl 0;
  xxh64WithSeed = xxh64Impl;
}
