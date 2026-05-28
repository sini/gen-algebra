{ lib, genLib, ... }:
let
  inherit (genLib) mkValidator runValidators;
  validators = [
    (mkValidator "has-addr" ({ addr, ... }: addr != "") "addr must not be empty")
  ];
  instances = {
    igloo = {
      addr = "10.0.1.1";
      role = "web";
    };
  };
  result = runValidators "host" validators instances;
in
{
  flake.tests.validator-pass.test-right-returned = {
    expr = result ? right;
    expected = true;
  };
  flake.tests.validator-pass.test-right-contains-instances = {
    expr = result.right;
    expected = instances;
  };
}
