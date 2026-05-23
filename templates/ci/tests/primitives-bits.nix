{ lib, genLib, ... }:
let
  inherit (genLib.pure.primitives.bits) bitShiftLeft bitShiftRight;
  inherit (genLib.pure.primitives.math) pow mod;
  shl = bitShiftLeft;
  shr = bitShiftRight;
  intMin = -9223372036854775807 - 1;
in
{
  primitives-bits.test-shl-zero-shift = {
    expr = shl 0 42;
    expected = 42;
  };
  primitives-bits.test-shl-one = {
    expr = shl 1 1;
    expected = 2;
  };
  primitives-bits.test-shl-sign-bit = {
    expr = shl 63 1;
    expected = intMin;
  };
  primitives-bits.test-shl-64-is-zero = {
    expr = shl 64 255;
    expected = 0;
  };
  primitives-bits.test-shr-zero-shift = {
    expr = shr 0 42;
    expected = 42;
  };
  primitives-bits.test-shr-basic = {
    expr = shr 1 8;
    expected = 4;
  };
  primitives-bits.test-shr-sign-bit = {
    expr = shr 1 (-1);
    expected = 9223372036854775807;
  };
  primitives-bits.test-shr-64-is-zero = {
    expr = shr 64 255;
    expected = 0;
  };
  primitives-bits.test-negative-shift-reverses = {
    expr = shl (-3) 16;
    expected = shr 3 16;
  };
  primitives-bits.test-shl-62-3 = {
    # 3 << 62 = 0xC000000000000000 = -4611686018427387904 signed
    expr = shl 62 3;
    expected = (-4611686018427387904);
  };
  primitives-bits.test-shl-62-2 = {
    # 2 << 62 = 0x8000000000000000 = intMin
    expr = shl 62 2;
    expected = (-9223372036854775807 - 1);
  };
  primitives-bits.test-pow-basic = {
    expr = pow 2 10;
    expected = 1024;
  };
  primitives-bits.test-pow-zero = {
    expr = pow 5 0;
    expected = 1;
  };
  primitives-bits.test-mod-basic = {
    expr = mod 7 3;
    expected = 1;
  };

  # bitShiftRight edge cases
  primitives-bits.test-shr-63-negative = {
    expr = shr 63 (-1);
    expected = 1;
  };
  primitives-bits.test-shr-63-positive = {
    expr = shr 63 42;
    expected = 0;
  };
  primitives-bits.test-shr-multi-negative = {
    expr = shr 2 (-4);
    # -4 unsigned = 0xFFFFFFFFFFFFFFFC, >> 2 = 0x3FFFFFFFFFFFFFFF = 4611686018427387903
    expected = 4611686018427387903;
  };

  # Math function tests
  primitives-bits.test-abs-positive = {
    expr = (genLib.pure.primitives.math).abs 42;
    expected = 42;
  };
  primitives-bits.test-abs-negative = {
    expr = (genLib.pure.primitives.math).abs (-7);
    expected = 7;
  };
  primitives-bits.test-abs-zero = {
    expr = (genLib.pure.primitives.math).abs 0;
    expected = 0;
  };
}
