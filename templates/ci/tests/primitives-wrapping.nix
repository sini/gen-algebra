{ lib, genLib, ... }:
let
  inherit (genLib.pure.primitives.wrapping)
    wrapAdd
    wrapSub
    wrapMul
    wrapNeg
    rotl64
    ;
  maxInt = 9223372036854775807;
  minInt = -9223372036854775807 - 1;
in
{
  primitives-wrapping.test-add-no-overflow = {
    expr = wrapAdd 100 200;
    expected = 300;
  };
  primitives-wrapping.test-add-positive-overflow = {
    expr = wrapAdd maxInt 1;
    expected = minInt;
  };
  primitives-wrapping.test-add-negative-overflow = {
    expr = wrapAdd minInt (-1);
    expected = maxInt;
  };
  primitives-wrapping.test-sub-identity = {
    expr = wrapSub 12345 12345;
    expected = 0;
  };
  primitives-wrapping.test-sub-underflow = {
    expr = wrapSub 0 1;
    expected = -1;
  };
  primitives-wrapping.test-neg-one = {
    expr = wrapNeg 1;
    expected = -1;
  };
  primitives-wrapping.test-neg-zero = {
    expr = wrapNeg 0;
    expected = 0;
  };
  primitives-wrapping.test-mul-simple = {
    expr = wrapMul 6 7;
    expected = 42;
  };
  primitives-wrapping.test-mul-primes = {
    # PRIME64_1 * PRIME64_2 mod 2^64
    expr = wrapMul (-7046029288634856825) (-4417276706812531889);
    expected = (-2381459717836149591);
  };
  primitives-wrapping.test-rotl64-basic = {
    expr = rotl64 1 1;
    expected = 2;
  };
  primitives-wrapping.test-rotl64-wrap = {
    expr = rotl64 minInt 1;
    expected = 1;
  };
  primitives-wrapping.test-rotl64-identity = {
    expr = rotl64 42 0;
    expected = 42;
  };
}
