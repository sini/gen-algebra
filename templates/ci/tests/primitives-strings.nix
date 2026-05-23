{ lib, genLib, ... }:
let
  inherit (genLib.pure.primitives.strings)
    charAt
    indexOfChar
    lastIndexOfChar
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
  primitives-strings.test-last-index-of-char = {
    expr = lastIndexOfChar "l" "hello";
    expected = 3;
  };
  primitives-strings.test-last-index-of-char-none = {
    expr = lastIndexOfChar "z" "hello";
    expected = null;
  };
  primitives-strings.test-char-at-negative = {
    expr = charAt (-1) "hello";
    expected = null;
  };
  primitives-strings.test-index-of-char-not-found = {
    expr = indexOfChar "z" "hello";
    expected = null;
  };
  primitives-strings.test-to-chars-empty = {
    expr = toChars "";
    expected = [ ];
  };
  primitives-strings.test-remove-chars-list = {
    expr = removeChars [ "a" "e" ] "abcde";
    expected = "bcd";
  };
  primitives-strings.test-lpad-string-noop = {
    expr = lpadString "0" 2 "hello";
    expected = "hello";
  };
  primitives-strings.test-rpad-string-noop = {
    expr = rpadString "." 2 "hello";
    expected = "hello";
  };
}
