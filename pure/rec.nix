# Record algebra with scoped labels (Leijen 2005).
# Self-referencing attrset via let-binding for derived operations (added in later tasks).
let
  self = {
    empty = { __entries = {}; __order = []; };

    extend = r: l: v:
      let
        existing = r.__entries.${l} or [];
        newOrder = if existing == [] then r.__order ++ [ l ] else r.__order;
      in {
        __entries = r.__entries // { ${l} = [ v ] ++ existing; };
        __order = newOrder;
      };

    select = r: l:
      if r.__entries ? ${l} && r.__entries.${l} != []
      then builtins.head r.__entries.${l}
      else throw "rec: no field '${l}'";

    restrict = r: l:
      if !(r.__entries ? ${l}) then r
      else
        let
          tail = builtins.tail r.__entries.${l};
        in
        if tail == [] then {
          __entries = builtins.removeAttrs r.__entries [ l ];
          __order = builtins.filter (x: x != l) r.__order;
        } else {
          __entries = r.__entries // { ${l} = tail; };
          __order = r.__order;
        };

    has = r: l: r.__entries ? ${l} && r.__entries.${l} != [];

    depth = r: l:
      if r.__entries ? ${l} then builtins.length r.__entries.${l}
      else 0;
  };
in self
