{ lib, genLib, ... }:
let
  inherit (genLib.pure.primitives.encoding)
    encodeBinary
    decodeBinary
    encodeBinaryBytes
    ;
in
{
  primitives-encoding.test-encode-zero = {
    expr = encodeBinary 0;
    expected = [ 0 ];
  };
  primitives-encoding.test-encode-42 = {
    expr = encodeBinary 42;
    expected = [
      1
      0
      1
      0
      1
      0
    ];
  };
  primitives-encoding.test-decode-roundtrip = {
    expr = decodeBinary (encodeBinary 42);
    expected = 42;
  };
  primitives-encoding.test-decode-roundtrip-255 = {
    expr = decodeBinary (encodeBinary 255);
    expected = 255;
  };
  primitives-encoding.test-encode-bytes-padding = {
    # 42 = 101010 (6 bits), padded to 8 bits
    expr = builtins.length (encodeBinaryBytes 42);
    expected = 8;
  };
  primitives-encoding.test-encode-one = {
    expr = encodeBinary 1;
    expected = [ 1 ];
  };
  primitives-encoding.test-encode-power-of-2 = {
    expr = encodeBinary 8;
    expected = [ 1 0 0 0 ];
  };
  primitives-encoding.test-encode-bytes-value = {
    expr = encodeBinaryBytes 42;
    expected = [ 0 0 1 0 1 0 1 0 ];
  };
  primitives-encoding.test-encode-bytes-aligned = {
    expr = encodeBinaryBytes 255;
    expected = [ 1 1 1 1 1 1 1 1 ];
  };
  primitives-encoding.test-decode-direct = {
    expr = decodeBinary [ 1 0 1 ];
    expected = 5;
  };
  primitives-encoding.test-decode-zero = {
    expr = decodeBinary [ 0 ];
    expected = 0;
  };
  primitives-encoding.test-decode-empty = {
    expr = decodeBinary [ ];
    expected = 0;
  };
}
