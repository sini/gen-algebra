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

    emit = r:
      builtins.mapAttrs (_: builtins.head) r.__entries;

    emitAll = r: fullLabels:
      let
        isFull = l: builtins.elem l fullLabels;
      in
      builtins.mapAttrs (
        l: stack: if isFull l then stack else builtins.head stack
      ) r.__entries;

    fromAttrs =
      attrs:
      let
        names = builtins.attrNames attrs;
      in
      {
        __entries = builtins.mapAttrs (_: v: [ v ]) attrs;
        __order = names;
      };

    update =
      r: l: v:
      if !(r.__entries ? ${l}) || r.__entries.${l} == [ ]
      then throw "rec: no field '${l}' to update"
      else {
        __entries = r.__entries // {
          ${l} = [ v ] ++ builtins.tail r.__entries.${l};
        };
        __order = r.__order;
      };

    upsert = r: l: v: self.extend (self.restrict r l) l v;

    rename = r: old: new: self.extend (self.restrict r old) new (self.select r old);

    labels = r: r.__order;

    show =
      r:
      let
        showStack =
          l: stack:
          "${l} = [${builtins.concatStringsSep ", " (builtins.map (v: builtins.toJSON v) stack)}]";
      in
      "{ ${builtins.concatStringsSep "; " (builtins.map (l: showStack l r.__entries.${l}) r.__order)} }";

    showCompact =
      r:
      let
        showField = l: "${l} = ${builtins.toJSON (builtins.head r.__entries.${l})}";
      in
      "{ ${builtins.concatStringsSep "; " (builtins.map showField r.__order)} }";
  };
in self
