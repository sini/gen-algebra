{ lib, genLib, ... }:
let
  inherit (genLib.pure.primitives.strings)
    charAt
    indexOfChar
    removeChars
    lpadString
    rpadString
    toChars
    ;
in
{
  primitives-strings.test-char-at = {
    expr = charAt 0 "hello";
    expected = "h";
  };
  primitives-strings.test-char-at-oob = {
    expr = charAt 10 "hi";
    expected = null;
  };
  primitives-strings.test-index-of-char = {
    expr = indexOfChar "l" "hello";
    expected = 2;
  };
  primitives-strings.test-remove-chars = {
    expr = removeChars "aeiou" "hello";
    expected = "hll";
  };
  primitives-strings.test-lpad-string = {
    expr = lpadString "0" 5 "hi";
    expected = "000hi";
  };
  primitives-strings.test-rpad-string = {
    expr = rpadString "." 5 "hi";
    expected = "hi...";
  };
  primitives-strings.test-to-chars = {
    expr = toChars "abc";
    expected = [
      "a"
      "b"
      "c"
    ];
  };
}
