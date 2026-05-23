{ lib, genLib, ... }:
let
  inherit (genLib.pure) xxh64 xxh64WithSeed;
in
{
  xxh64.test-empty = {
    expr = xxh64 "";
    expected = "ef46db3751d8e999";
  };
  xxh64.test-single-char = {
    expr = xxh64 "a";
    expected = "d24ec4f1a98c6e5b";
  };
  xxh64.test-abc = {
    expr = xxh64 "abc";
    expected = "44bc2cf5ad770999";
  };
  xxh64.test-hello-world = {
    expr = xxh64 "Hello, World!";
    expected = "c49aacf8080fe47f";
  };
  xxh64.test-31-bytes = {
    expr = xxh64 "abcdefghijklmnopqrstuvwxyz01234";
    expected = "16058c7b947da137";
  };
  xxh64.test-32-bytes = {
    expr = xxh64 "abcdefghijklmnopqrstuvwxyz012345";
    expected = "bf2cd639b4143b80";
  };
  xxh64.test-33-bytes = {
    expr = xxh64 "abcdefghijklmnopqrstuvwxyz0123456";
    expected = "4f89e4082bcbf673";
  };
  xxh64.test-64-bytes = {
    expr = xxh64 "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZxy";
    expected = "8c29ab81803fa6d0";
  };
  xxh64.test-json-identity = {
    expr = xxh64 "{\"hostname\":\"igloo\",\"user\":\"tux\"}";
    expected = "6df43dd6492300df";
  };
  xxh64.test-256-zeros = {
    expr = xxh64 (builtins.concatStringsSep "" (builtins.genList (_: "0") 256));
    expected = "43f6c51af9f03845";
  };
  xxh64.test-output-length = {
    expr = builtins.stringLength (xxh64 "test");
    expected = 16;
  };
  xxh64.test-seeded = {
    expr = xxh64WithSeed 42 "abc";
    expected = "13c1d910702770e6";
  };
}
