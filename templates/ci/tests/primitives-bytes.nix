{ lib, genLib, ... }:
let
  inherit (genLib.pure.primitives.bytes)
    byteTable
    stringToBytes
    readLE64
    readLE32
    ;
in
{
  primitives-bytes.test-ascii-A = {
    expr = byteTable.${"A"};
    expected = 65;
  };
  primitives-bytes.test-ascii-zero = {
    expr = byteTable.${"0"};
    expected = 48;
  };
  primitives-bytes.test-string-to-bytes-abc = {
    expr = stringToBytes "ABC";
    expected = [
      65
      66
      67
    ];
  };
  primitives-bytes.test-string-to-bytes-empty = {
    expr = stringToBytes "";
    expected = [ ];
  };
  primitives-bytes.test-read-le64-one = {
    expr = readLE64 [
      1
      0
      0
      0
      0
      0
      0
      0
    ] 0;
    expected = 1;
  };
  primitives-bytes.test-read-le64-256 = {
    expr = readLE64 [
      0
      1
      0
      0
      0
      0
      0
      0
    ] 0;
    expected = 256;
  };
  primitives-bytes.test-read-le32-basic = {
    expr = readLE32 [ 255 0 0 0 ] 0;
    expected = 255;
  };
  primitives-bytes.test-read-le32-offset = {
    expr = readLE32 [ 0 0 1 0 0 0 ] 2;
    expected = 1;
  };
}
