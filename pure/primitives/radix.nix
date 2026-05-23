# Integer to hexadecimal string conversion — builtins only.
# intToHex and intToHexPadded require non-negative inputs.
# Negative values silently return "0" (no sign handling).
let
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

  intToHex =
    let
      accumulate =
        num: acc:
        if num > 0 then
          accumulate (num / 16) ((builtins.elemAt hexDigits (num - (num / 16) * 16)) + acc)
        else
          acc;
    in
    num: if num == 0 then "0" else accumulate num "";

  # Pad hex output to `width` chars with leading zeros.
  # Max supported width: 16 (sufficient for 64-bit values).
  intToHexPadded =
    width: num:
    let
      zeros = "0000000000000000";
      hex = intToHex num;
      need = width - builtins.stringLength hex;
    in
    if need > 0 then (builtins.substring 0 need zeros) + hex else hex;
in
{
  inherit intToHex intToHexPadded;
}
