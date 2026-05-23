# Byte-level string operations — builtins only.
# Generates single-byte-string → integer mappings at eval time.
let
  bits = import ./bits.nix;
  inherit (bits) bitShiftLeft bitShiftRight;
  inherit (builtins)
    bitOr
    elemAt
    genList
    stringLength
    substring
    fromJSON
    ;

  hexDigits = [
    "0"
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "a"
    "b"
    "c"
    "d"
    "e"
    "f"
  ];

  toHex4 =
    n:
    let
      d3 = n / 4096;
      r3 = n - d3 * 4096;
      d2 = r3 / 256;
      r2 = r3 - d2 * 256;
      d1 = r2 / 16;
      d0 = r2 - d1 * 16;
    in
    elemAt hexDigits d3 + elemAt hexDigits d2 + elemAt hexDigits d1 + elemAt hexDigits d0;

  mkUnicodeChar = cp: fromJSON "\"\\u${toHex4 cp}\"";

  # Generate single-byte string for each byte value 0-255.
  mkByteString =
    b:
    if b < 128 then
      mkUnicodeChar b
    else if b < 192 then
      # 128-191: second byte of 2-byte UTF-8 from U+0080-U+00BF
      substring 1 1 (mkUnicodeChar b)
    else
      # 192-255: first byte of 2-byte UTF-8 from higher codepoints
      # NOTE: bytes 192-193 (0xC0-0xC1) are invalid UTF-8 leading bytes.
      # The formula below maps them to wrong values. Since builtins.toJSON
      # produces pure ASCII (bytes 0-127 only), this is acceptable for
      # gen's identity hashing use case.
      substring 0 1 (mkUnicodeChar ((b - 194) * 64 + 128));

  # Attrset: single-byte string → integer (0-255)
  byteTable = builtins.listToAttrs (
    genList (b: {
      name = mkByteString b;
      value = b;
    }) 256
  );

  # String → list of byte integers.
  stringToBytes = str: genList (i: byteTable.${substring i 1 str}) (stringLength str);

  # Read 8 bytes at offset as little-endian 64-bit integer.
  readLE64 =
    bytes: offset:
    let
      b = i: elemAt bytes (offset + i);
    in
    bitOr (bitOr (bitOr (b 0) (bitShiftLeft 8 (b 1))) (bitOr (bitShiftLeft 16 (b 2)) (bitShiftLeft 24 (b 3)))) (
      bitOr (bitOr (bitShiftLeft 32 (b 4)) (bitShiftLeft 40 (b 5))) (
        bitOr (bitShiftLeft 48 (b 6)) (bitShiftLeft 56 (b 7))
      )
    );

  # Read 4 bytes at offset as little-endian 32-bit integer.
  readLE32 =
    bytes: offset:
    let
      b = i: elemAt bytes (offset + i);
    in
    bitOr (bitOr (b 0) (bitShiftLeft 8 (b 1))) (bitOr (bitShiftLeft 16 (b 2)) (bitShiftLeft 24 (b 3)));
in
{
  inherit
    byteTable
    stringToBytes
    readLE64
    readLE32
    mkByteString
    ;
}
