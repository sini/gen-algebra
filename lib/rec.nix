# Record algebra with scoped labels (Leijen 2005).
let
  self = {
    empty = {
      __entries = { };
      __order = [ ];
    };

    extend =
      r: l: v:
      let
        existing = r.__entries.${l} or [ ];
        newOrder = if existing == [ ] then r.__order ++ [ l ] else r.__order;
      in
      {
        __entries = r.__entries // {
          ${l} = [ v ] ++ existing;
        };
        __order = newOrder;
      };

    select =
      r: l:
      if r.__entries ? ${l} && r.__entries.${l} != [ ] then
        builtins.head r.__entries.${l}
      else
        throw "rec: no field '${l}'";

    restrict =
      r: l:
      if !(r.__entries ? ${l}) then
        r
      else
        let
          tail = builtins.tail r.__entries.${l};
        in
        if tail == [ ] then
          {
            __entries = builtins.removeAttrs r.__entries [ l ];
            __order = builtins.filter (x: x != l) r.__order;
          }
        else
          {
            __entries = r.__entries // {
              ${l} = tail;
            };
            __order = r.__order;
          };

    has = r: l: r.__entries ? ${l} && r.__entries.${l} != [ ];

    depth = r: l: if r.__entries ? ${l} then builtins.length r.__entries.${l} else 0;

    emit = r: builtins.mapAttrs (_: builtins.head) r.__entries;

    emitAll =
      r: fullLabels:
      let
        isFull = l: builtins.elem l fullLabels;
      in
      builtins.mapAttrs (l: stack: if isFull l then stack else builtins.head stack) r.__entries;

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
      if !(r.__entries ? ${l}) || r.__entries.${l} == [ ] then
        throw "rec: no field '${l}' to update"
      else
        {
          __entries = r.__entries // {
            ${l} = [ v ] ++ builtins.tail r.__entries.${l};
          };
          __order = r.__order;
        };

    upsert =
      r: l: v:
      self.extend (self.restrict r l) l v;

    rename =
      r: old: new:
      self.extend (self.restrict r old) new (self.select r old);

    labels = r: r.__order;

    show =
      r:
      let
        showStack =
          l: stack: "${l} = [${builtins.concatStringsSep ", " (builtins.map (v: builtins.toJSON v) stack)}]";
      in
      "{ ${builtins.concatStringsSep "; " (builtins.map (l: showStack l r.__entries.${l}) r.__order)} }";

    showCompact =
      r:
      let
        showField = l: "${l} = ${builtins.toJSON (builtins.head r.__entries.${l})}";
      in
      "{ ${builtins.concatStringsSep "; " (builtins.map showField r.__order)} }";

    # Left-biased combination (⊕). Left's stacks go above right's stacks.
    # Label order: left's order first, then right-only labels.
    # O(n+m) via set-based dedup instead of linear scan.
    combine =
      a: b:
      let
        aSet = builtins.listToAttrs (
          builtins.map (l: {
            name = l;
            value = true;
          }) a.__order
        );
        allLabels = a.__order ++ builtins.filter (l: !(aSet ? ${l})) b.__order;
        mergeStacks =
          l:
          let
            aStack = a.__entries.${l} or [ ];
            bStack = b.__entries.${l} or [ ];
          in
          aStack ++ bStack;
        entries = builtins.listToAttrs (
          builtins.map (l: {
            name = l;
            value = mergeStacks l;
          }) allLabels
        );
      in
      {
        __entries = entries;
        __order = allLabels;
      };

    # Smalltalk direction: delta(parent) ⊕ parent — delta wins
    mixin = delta: parent: self.combine (delta parent) parent;

    # Instantiated Beta inheritance (Bracha 1990 §2.2) with inner = ∅.
    # The general form C'(inner) = P'(Δ'(inner) ⊕ inner) ⊕ Δ'(inner) is
    # handled by `compose`, which preserves the inner parameter for further
    # composition. This is the leaf form suitable for direct application.
    mixinBeta =
      prefix: suffix:
      let
        inner = self.empty;
      in
      self.combine (prefix (self.combine suffix inner)) suffix;

    # Mixin composition: M1 ⋆ M2 = fun(i) M1(M2(i) ⊕ i) ⊕ M2(i)
    compose =
      m1: m2: i:
      let
        m2i = m2 i;
      in
      self.combine (m1 (self.combine m2i i)) m2i;

    satisfies = r: required: builtins.all (l: self.has r l) required;

    assertSatisfies =
      r: required:
      let
        missing = builtins.filter (l: !(self.has r l)) required;
      in
      if missing == [ ] then
        r
      else
        throw "rec: missing required fields: ${builtins.concatStringsSep ", " missing}";

    # Fold ordered layers with per-field merge strategies.
    # layers: least-specific first (base before overrides), last wins. CSS cascade order.
    # strategies: field → "replace"|"append"|"recursive".
    foldLayers =
      {
        strategies ? { },
        defaults ? { },
        layers ? [ ],
      }:
      let
        allKeySet = builtins.foldl' (acc: l: acc // builtins.mapAttrs (_: _: true) l) (builtins.mapAttrs (
          _: _: true
        ) defaults) layers;
        allKeys = builtins.attrNames allKeySet;

        resolveField =
          name:
          let
            strategy = strategies.${name} or "replace";
            contributions = builtins.filter (l: l ? ${name}) layers;
            hasContrib = contributions != [ ];
          in
          if !hasContrib then
            defaults.${name} or null
          else if strategy == "replace" then
            builtins.foldl' (_: l: l.${name}) (defaults.${name} or null) contributions
          else if strategy == "append" then
            builtins.foldl' (acc: l: acc ++ l.${name}) (defaults.${name} or [ ]) contributions
          else if strategy == "recursive" then
            builtins.foldl' (acc: l: acc // l.${name}) (defaults.${name} or { }) contributions
          else
            throw "rec.foldLayers: unknown strategy '${strategy}' for field '${name}'";
      in
      builtins.listToAttrs (
        builtins.map (k: {
          name = k;
          value = resolveField k;
        }) allKeys
      );

    # Like foldLayers, but also returns a per-field provenance trace, in one pass.
    # value is byte-identical to (foldLayers { inherit strategies defaults layers; })
    # ON THE STRATEGIES BOTH ACCEPT — "replace" (explicit or implicit), "append",
    # "recursive" — which is what the value-identity guards in
    # ci/tests/rec-fold-layers-traced.nix hold. The agreement is not unconditional:
    # "semilattice-set" resolves here and foldLayers refuses it, so the two are siblings
    # over a shared domain rather than one primitive with two return shapes.
    # layerNames: opaque labels aligned 1:1 with layers (least-specific first). Any value
    # is admissible; the fold stores each verbatim into provenance.<field>[].layer and
    # never reads one.
    # provenance.<field> = ordered [{ layer; value; }] — default first (when present),
    # then each contributing layer. For "replace" the LAST entry is effective; the
    # leading default is informational. For "append"/"recursive" the listed values
    # are the accumulation.
    #
    # entryTransform: an optional refinement of the emission, `field -> entry -> entry'`,
    # applied to every entry of that field's chain, the default entry included. It exists so
    # that a derived reading of an entry — the entry's value under a substitution the caller
    # owns — is emitted BY the traced fold rather than re-mapped over its output afterwards.
    # It is handed the field name because a refinement that cannot see which field it refines
    # cannot report one. The fold learns no vocabulary from it: the transform is opaque here
    # exactly as layer labels are.
    #
    # NON-INTERFERENCE. Application is per entry and demand-driven (call-by-need, Launchbury
    # 1993 §2 — what `map` inherits here): forcing a chain's spine, one entry's own transformed
    # record, or any sibling entry never applies the transform to another entry, and forcing
    # `.value` never applies it at all. So a transform lazy in its derived part leaves a
    # diverging entry harmless to the rest of the trace, which is the property that separates
    # this from a consumer-side `map`. Absent, the chain is emitted untransformed and no
    # per-entry application is allocated.
    foldLayersTraced =
      {
        strategies ? { },
        defaults ? { },
        layers ? [ ],
        layerNames ? [ ],
        defaultLabel ? "default",
        entryTransform ? null,
      }:
      assert builtins.length layerNames == builtins.length layers;
      let
        nLayers = builtins.length layers;
        indexed = builtins.genList (i: {
          name = builtins.elemAt layerNames i;
          layer = builtins.elemAt layers i;
        }) nLayers;

        allKeySet = builtins.foldl' (acc: l: acc // builtins.mapAttrs (_: _: true) l) (builtins.mapAttrs (
          _: _: true
        ) defaults) layers;
        allKeys = builtins.attrNames allKeySet;

        resolve =
          name:
          let
            strategy = strategies.${name} or "replace";
            contribs = builtins.filter (e: e.layer ? ${name}) indexed;
            hasContrib = contribs != [ ];
            hasDefault = defaults ? ${name};
            value =
              if !hasContrib then
                defaults.${name} or null
              else if strategy == "replace" then
                builtins.foldl' (_: e: e.layer.${name}) (defaults.${name} or null) contribs
              else if strategy == "append" then
                builtins.foldl' (acc: e: acc ++ e.layer.${name}) (defaults.${name} or [ ]) contribs
              else if strategy == "recursive" then
                builtins.foldl' (acc: e: acc // e.layer.${name}) (defaults.${name} or { }) contribs
              else if strategy == "semilattice-set" then
                builtins.foldl' (
                  acc: e: builtins.foldl' (a2: x: if builtins.elem x a2 then a2 else a2 ++ [ x ]) acc e.layer.${name}
                ) (defaults.${name} or [ ]) contribs
              else
                throw "rec.foldLayersTraced: unknown strategy '${strategy}' for field '${name}'";
            defaultEntry =
              if hasDefault then
                [
                  {
                    layer = defaultLabel;
                    value = defaults.${name};
                  }
                ]
              else if !hasContrib then
                [
                  {
                    layer = defaultLabel;
                    value = null;
                  }
                ]
              else
                [ ];
            contribEntries = builtins.map (e: {
              layer = e.name;
              value = e.layer.${name};
            }) contribs;
            entries = defaultEntry ++ contribEntries;
          in
          {
            inherit value;
            provenance = if entryTransform == null then entries else builtins.map (entryTransform name) entries;
          };

        resolved = builtins.listToAttrs (
          builtins.map (k: {
            name = k;
            value = resolve k;
          }) allKeys
        );
      in
      {
        value = builtins.mapAttrs (_: r: r.value) resolved;
        provenance = builtins.mapAttrs (_: r: r.provenance) resolved;
      };

    # Flatten nested attrset to dot-separated keys.
    # Halts recursion at fields whose strategy is "recursive".
    flattenAttrs =
      {
        strategies ? { },
        prefix ? "",
      }:
      attrs:
      let
        go =
          pfx: a:
          builtins.foldl' (
            acc: k:
            let
              v = a.${k};
              key = if pfx == "" then k else "${pfx}.${k}";
              strategy = strategies.${key} or null;
            in
            if builtins.isAttrs v && v != { } && strategy != "recursive" then
              acc // go key v
            else
              acc // { ${key} = v; }
          ) { } (builtins.attrNames a);
      in
      go prefix attrs;

    # Unflatten dot-separated keys back to nested attrset.
    unflattenAttrs =
      flat:
      let
        setByPath =
          path: value:
          if builtins.length path == 1 then
            { ${builtins.head path} = value; }
          else
            { ${builtins.head path} = setByPath (builtins.tail path) value; };
        recursiveUpdate =
          a: b:
          a
          // builtins.mapAttrs (
            k: bv:
            if a ? ${k} && builtins.isAttrs a.${k} && builtins.isAttrs bv then recursiveUpdate a.${k} bv else bv
          ) b;
      in
      builtins.foldl' (
        acc: key:
        let
          parts = builtins.filter builtins.isString (builtins.split "\\." key);
          value = flat.${key};
        in
        recursiveUpdate acc (setByPath parts value)
      ) { } (builtins.attrNames flat);

    # foldLayers for nested attrsets: flatten → foldLayers → unflatten.
    foldNestedLayers =
      {
        strategies ? { },
        defaults ? { },
        layers ? [ ],
      }:
      let
        flatDefaults = self.flattenAttrs { inherit strategies; } defaults;
        flatLayers = map (l: self.flattenAttrs { inherit strategies; } l) layers;
        folded = self.foldLayers {
          inherit strategies;
          defaults = flatDefaults;
          layers = flatLayers;
        };
      in
      self.unflattenAttrs folded;
  };
in
self
