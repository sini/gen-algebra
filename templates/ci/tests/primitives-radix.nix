{ lib, genLib, ... }:
let
  inherit (genLib.pure.primitives.radix) intToHex intToHexPadded;
in
{
  primitives-radix.test-zero = {
    expr = intToHex 0;
    expected = "0";
  };
  primitives-radix.test-255 = {
    expr = intToHex 255;
    expected = "ff";
  };
  primitives-radix.test-256 = {
    expr = intToHex 256;
    expected = "100";
  };
  primitives-radix.test-padded = {
    expr = intToHexPadded 16 255;
    expected = "00000000000000ff";
  };
  primitives-radix.test-padded-zero = {
    expr = intToHexPadded 4 0;
    expected = "0000";
  };
  primitives-radix.test-single-digit = {
    expr = intToHex 15;
    expected = "f";
  };
  primitives-radix.test-one = {
    expr = intToHex 1;
    expected = "1";
  };
  primitives-radix.test-large = {
    expr = intToHex 65535;
    expected = "ffff";
  };
  primitives-radix.test-padded-no-truncate = {
    expr = intToHexPadded 1 255;
    expected = "ff";
  };
}
