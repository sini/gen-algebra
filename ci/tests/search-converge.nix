{ lib, genLib, ... }:
let
  inherit (genLib) search mkIntensional;
in
{
  search-converge.test-basic = {
    expr =
      let
        s0 = search.insert "k" "v1" search.empty;
        s1 = search.on "k" (v: s: search.emit [ "saw:${v}" ] s) s0;
        final = search.converge s1;
      in
      final.results;
    expected = [ "saw:v1" ];
  };

  search-converge.test-multi-round = {
    expr =
      let
        s0 = search.insert "trigger" "go" search.empty;
        s1 = search.on "trigger" (_v: s: search.insert "data" "from-A" s) s0;
        s2 = search.on "data" (v: s: search.emit [ "B-saw:${v}" ] s) s1;
        final = search.converge s2;
      in
      final.results;
    expected = [ "B-saw:from-A" ];
  };

  search-converge.test-stability = {
    expr =
      let
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" (v: s: search.emit [ v ] s) s0;
        first = search.converge s1;
        second = search.converge first;
      in
      {
        firstResults = first.results;
        secondResults = second.results;
      };
    expected = {
      firstResults = [ "v" ];
      secondResults = [ "v" ];
    };
  };

  search-converge.test-unwatched-key = {
    expr =
      let
        s0 = search.insert "other" "v" search.empty;
        s1 = search.on "missing" (_v: s: search.emit [ "should-not-fire" ] s) s0;
        final = search.converge s1;
      in
      final.results;
    expected = [ ];
  };

  search-converge.test-dynamic-registration = {
    expr =
      let
        s0 = search.insert "phase1" "go" search.empty;
        s1 = search.insert "phase2" "data" s0;
        s2 = search.on "phase1" (
          _v: s: search.on "phase2" (v2: s2: search.emit [ "dynamic:${v2}" ] s2) s
        ) s1;
        final = search.converge s2;
      in
      final.results;
    expected = [ "dynamic:data" ];
  };

  search-converge.test-intensional-dedup = {
    expr =
      let
        counter = mkIntensional "my-counter" { } (v: s: search.emit [ "counted:${v}" ] s);
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" counter s0;
        s2 = search.on "k" counter s1;
        final = search.converge s2;
      in
      final.results;
    expected = [ "counted:v" ];
  };

  search-converge.test-empty = {
    expr = search.converge search.empty;
    expected = search.empty;
  };

  search-converge.test-bounded-self-insert = {
    expr =
      let
        s0 = search.insert "k" "start" search.empty;
        s1 = search.on "k" (
          v: s:
          if v == "start" then
            search.insert "k" "done" (search.emit [ "processed:${v}" ] s)
          else
            search.emit [ "processed:${v}" ] s
        ) s0;
        final = search.converge s1;
      in
      final.results;
    expected = [
      "processed:start"
      "processed:done"
    ];
  };

  search-converge.test-on-before-insert = {
    expr =
      let
        s0 = search.on "k" (v: s: search.emit [ "saw:${v}" ] s) search.empty;
        s1 = search.insert "k" "late-arrival" s0;
        final = search.converge s1;
      in
      final.results;
    expected = [ "saw:late-arrival" ];
  };

  search-converge.test-non-intensional-duplicates-fire-independently = {
    expr =
      let
        fn = v: s: search.emit [ "fired:${v}" ] s;
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" fn s0;
        s2 = search.on "k" fn s1;
        final = search.converge s2;
      in
      final.results;
    expected = [
      "fired:v"
      "fired:v"
    ];
  };
}
