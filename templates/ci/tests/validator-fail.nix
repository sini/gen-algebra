{ lib, genLib, ... }:
let
  inherit (genLib) mkValidator runValidators;
  validators = [
    (mkValidator "has-addr" ({ addr, ... }: addr != "") "addr must not be empty")
  ];
  instances = {
    bad = {
      addr = "";
    };
  };
  result = runValidators "host" validators instances;
in
{
  validator-fail.test-left-returned = {
    expr = result ? left;
    expected = true;
  };
  validator-fail.test-error-has-instance-name = {
    expr = (lib.head result.left).name;
    expected = "bad";
  };
  validator-fail.test-error-has-validator-name = {
    expr = (lib.head result.left).validator;
    expected = "has-addr";
  };
}
