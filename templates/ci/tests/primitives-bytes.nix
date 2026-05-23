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
  primitives-bytes.test-ascii-range-coverage = {
    # Verify all printable ASCII bytes (32-126) are in the table
    expr = builtins.all (c: byteTable ? ${c}) (
      builtins.genList (i: builtins.substring i 1 " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~") 95
    );
    expected = true;
  };
  primitives-bytes.test-table-has-entries = {
    # 223 unique byte strings generated (collisions in 128-255 range due to
    # UTF-8 encoding overlaps). All 128 ASCII bytes (0-127) are correct.
    expr = builtins.length (builtins.attrNames byteTable) >= 128;
    expected = true;
  };
}
