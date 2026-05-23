# Bit shift operations for signed 64-bit Nix integers.
# Handles the sign bit correctly for unsigned interpretation.
# Origin: bird-nix-lib (Unlicense), rewritten to builtins-only.
let
  inherit (builtins)
    foldl'
    elemAt
    genList
    bitAnd
    ;

  # Lookup table: masksLut[n] = 2^n for n in 0..62
  masksLut = genList (n: foldl' (a: _: a * 2) 1 (genList (_: 0) n)) 63;

  # Nix signed 64-bit boundaries
  # Split to avoid Nix parser overflow on INT_MIN literal
  intMin = -9223372036854775807 - 1;
  intMax = 9223372036854775807;

  bitShiftLeft =
    shift: bits:
    if shift >= 64 then
      0
    else if shift == 0 then
      bits
    else if shift < 0 then
      bitShiftRight (-shift) bits
    else if shift == 63 then
      # Only the lowest bit survives and becomes the sign bit
      if bitAnd bits 1 != 0 then intMin else 0
    else
      let
        inv = 63 - shift;
        mask = if inv >= 62 then intMax else (elemAt masksLut (inv + 1)) - 1;
        masked = bitAnd bits mask;
        checker = if inv == 63 then intMin else elemAt masksLut inv;
        negate = bitAnd bits checker != 0;
        mult = elemAt masksLut shift;
        valMasked = if negate then bitAnd masked (mask - checker) else masked;
        result = valMasked * mult;
      in
      if negate then result + intMin else result;

  bitShiftRight =
    shift: bits:
    if shift >= 64 then
      0
    else if shift == 0 then
      bits
    else if shift < 0 then
      bitShiftLeft (-shift) bits
    else if shift == 63 then
      if bits < 0 then 1 else 0
    else
      let
        negate = bits < 0;
        # Clear sign bit, divide, restore high bit if needed
        cleared = if negate then bitAnd bits intMax else bits;
        result = cleared / (elemAt masksLut shift);
        highBit = elemAt masksLut (63 - shift);
      in
      if negate then result + highBit else result;
in
{
  inherit bitShiftLeft bitShiftRight;
}
