{ lib, genLib, ... }:
let
  inherit (genLib) mkIdentity;
in
{
  identity-standalone.test-deterministic = {
    expr =
      let
        a = mkIdentity {
          name = "host";
          fields = {
            hostname = "igloo";
          };
        };
        b = mkIdentity {
          name = "host";
          fields = {
            hostname = "igloo";
          };
        };
      in
      a == b;
    expected = true;
  };

  identity-standalone.test-different-name-different-hash = {
    expr =
      let
        a = mkIdentity {
          name = "host";
          fields = {
            x = "1";
          };
        };
        b = mkIdentity {
          name = "user";
          fields = {
            x = "1";
          };
        };
      in
      a == b;
    expected = false;
  };

  identity-standalone.test-different-fields-different-hash = {
    expr =
      let
        a = mkIdentity {
          name = "host";
          fields = {
            hostname = "igloo";
          };
        };
        b = mkIdentity {
          name = "host";
          fields = {
            hostname = "tundra";
          };
        };
      in
      a == b;
    expected = false;
  };

  identity-standalone.test-empty-fields = {
    expr =
      let
        a = mkIdentity { name = "thing"; };
        b = mkIdentity {
          name = "thing";
          fields = { };
        };
      in
      a == b;
    expected = true;
  };

  identity-standalone.test-prefix-format = {
    expr = builtins.substring 0 5 (mkIdentity {
      name = "host";
      fields = { };
    });
    expected = "host:";
  };
}
