# Integer to hexadecimal string conversion — builtins only.
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

  intToHexPadded =
    width: num:
    let
      hex = intToHex num;
      len = builtins.stringLength hex;
      pad = builtins.concatStringsSep "" (
        builtins.genList (_: "0") (if width > len then width - len else 0)
      );
    in
    pad + hex;
in
{
  inherit intToHex intToHexPadded;
}
