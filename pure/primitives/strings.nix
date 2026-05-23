# String operations — builtins only.
let
  lists = import ./lists.nix;
  inherit (builtins)
    stringLength
    substring
    concatStringsSep
    genList
    ;

  toChars = str: genList (i: substring i 1 str) (stringLength str);

  charAt = index: str: if index >= 0 && index < stringLength str then substring index 1 str else null;

  indexOfChar = char: str: lists.indexOf char (toChars str);

  lastIndexOfChar = char: str: lists.lastIndexOf char (toChars str);

  removeChars =
    chars: str:
    let
      charList = if builtins.isString chars then toChars chars else chars;
      replace = genList (_: "") (builtins.length charList);
    in
    builtins.replaceStrings charList replace str;

  lpadString =
    fillChar: totalLen: str:
    let
      padLen = totalLen - stringLength str;
      pad = concatStringsSep "" (genList (_: fillChar) (if padLen > 0 then padLen else 0));
    in
    pad + str;

  rpadString =
    fillChar: totalLen: str:
    let
      padLen = totalLen - stringLength str;
      pad = concatStringsSep "" (genList (_: fillChar) (if padLen > 0 then padLen else 0));
    in
    str + pad;
in
{
  inherit
    toChars
    charAt
    indexOfChar
    lastIndexOfChar
    removeChars
    lpadString
    rpadString
    ;
}
