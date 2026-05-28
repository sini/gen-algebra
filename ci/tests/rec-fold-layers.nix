{ lib, genLib, ... }:
let
  inherit (genLib.pure.record) foldLayers;
in
{
  flake.tests.rec-fold-layers = {
    test-replace-last-wins = {
      expr = foldLayers {
        strategies = { };
        defaults = {
          port = 80;
        };
        layers = [
          { port = 443; }
          { port = 8080; }
        ];
      };
      expected = {
        port = 8080;
      };
    };

    test-defaults-when-absent = {
      expr = foldLayers {
        strategies = { };
        defaults = {
          port = 80;
          workers = 4;
        };
        layers = [ { port = 8080; } ];
      };
      expected = {
        port = 8080;
        workers = 4;
      };
    };

    test-append-strategy = {
      expr = foldLayers {
        strategies = {
          allow = "append";
        };
        defaults = {
          allow = [ ];
        };
        layers = [
          { allow = [ "10.0.1.0/24" ]; }
          { allow = [ "10.0.2.0/24" ]; }
        ];
      };
      expected = {
        allow = [
          "10.0.1.0/24"
          "10.0.2.0/24"
        ];
      };
    };

    test-recursive-strategy = {
      expr = foldLayers {
        strategies = {
          locations = "recursive";
        };
        defaults = {
          locations = { };
        };
        layers = [
          {
            locations = {
              api = {
                proxy = "http://api:3000";
              };
            };
          }
          {
            locations = {
              root = {
                proxy = "http://app:8080";
              };
            };
          }
        ];
      };
      expected = {
        locations = {
          root = {
            proxy = "http://app:8080";
          };
          api = {
            proxy = "http://api:3000";
          };
        };
      };
    };

    test-mixed-strategies = {
      expr = foldLayers {
        strategies = {
          tags = "append";
        };
        defaults = {
          port = 80;
          tags = [ ];
        };
        layers = [
          {
            port = 443;
            tags = [ "ssl" ];
          }
          {
            port = 8080;
            tags = [ "web" ];
          }
        ];
      };
      expected = {
        port = 8080;
        tags = [
          "ssl"
          "web"
        ];
      };
    };

    test-new-keys-pass-through = {
      expr = foldLayers {
        strategies = { };
        defaults = {
          port = 80;
        };
        layers = [
          {
            port = 8080;
            extra = "bonus";
          }
        ];
      };
      expected = {
        port = 8080;
        extra = "bonus";
      };
    };

    test-empty-layers = {
      expr = foldLayers {
        strategies = { };
        defaults = {
          port = 80;
          workers = 4;
        };
        layers = [ ];
      };
      expected = {
        port = 80;
        workers = 4;
      };
    };

    test-recursive-conflict = {
      expr = foldLayers {
        strategies = {
          x = "recursive";
        };
        defaults = {
          x = { };
        };
        layers = [
          {
            x = {
              a = 1;
              b = 3;
            };
          }
          {
            x = {
              a = 2;
            };
          }
        ];
      };
      expected = {
        x = {
          a = 2;
          b = 3;
        };
      };
    };

    test-append-no-default = {
      expr = foldLayers {
        strategies = {
          tags = "append";
        };
        defaults = { };
        layers = [
          { tags = [ "a" ]; }
          { tags = [ "b" ]; }
        ];
      };
      expected = {
        tags = [
          "a"
          "b"
        ];
      };
    };

    test-empty-defaults = {
      expr = foldLayers {
        strategies = { };
        defaults = { };
        layers = [ { port = 8080; } ];
      };
      expected = {
        port = 8080;
      };
    };
  };
}
