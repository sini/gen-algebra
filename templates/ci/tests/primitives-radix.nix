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
}
