# The one first-order term algebra (den-hoag-lwbb1 unit 1).
#
# EXTRACTED from gen-bind's BodyTerm (`lib/crossing-term.nix` @ f924147): its formers, its
# `InertValue` walk, its closed primitive table, its refusal codes and witnesses, with gen-prelude
# replaced by builtins. WIDENED by the design's formers (specs/2026-10-01-gen-first-order-rules-design.md
# Sections 1 and 2): `default`, `ref`, the condition formers, declared coordinates and the clause check.
# Unifying spec: specs/2026-10-02-gen-first-order-rules-unifying-spec-v1.md; unit 1 spec:
# specs/2026-10-02-gen-algebra-term-extraction-spec.md.
#
# The mint is a CONSTRUCTOR PARAMETER, as `mkIntensional` takes it: gen-algebra imports nothing. An
# instance with no minting authority passes `null`, and every term it builds is then REFUSED (ADR-0034)
# by name, never minted by a formula of this file's own.
#
# Results are gen-algebra's own `either` sum: `{ right = v; }` or `{ left = { code; witness; }; }`.
#
# Academic: Reynolds 1972 — defunctionalization: a set of functions becomes a set of records
# interpreted by one function beneath the algebra.
hashIdentity:
let
  either = import ./either.nix;
  ok = either.right;
  refuse = code: witness: either.left { inherit code witness; };

  # The table's revision (ADR-0034 "required and total"). It covers every former's interpretation and
  # every primitive, because every term mints over it. Internal: no consumer reads it.
  revision = "1";

  # A refusal is recognised by its exact shape, so a slot payload that merely has a `left` is not one.
  isRefusal =
    v:
    builtins.isAttrs v
    && builtins.attrNames v == [ "left" ]
    && builtins.isAttrs v.left
    && v.left ? code;
  isTerm = v: builtins.isAttrs v && v ? __bodyTerm;
  elem = builtins.elem;
  unique = builtins.foldl' (acc: x: if elem x acc then acc else acc ++ [ x ]) [ ];
  findFirst =
    pred: default:
    builtins.foldl' (
      acc: v:
      if acc != default then
        acc
      else if pred v then
        v
      else
        acc
    ) default;
  firstRefusal = findFirst isRefusal null;
  # A former propagates a refusal sitting in an operand position, so a refused `lit` cannot be lost by
  # being nested.
  guard =
    operands: build:
    let
      bad = firstRefusal operands;
    in
    if bad != null then bad else build;
  traverse =
    xs: f:
    let
      rs = map f xs;
      bad = firstRefusal rs;
    in
    if bad != null then bad else ok (map (r: r.right) rs);
  traverseAttrs =
    m: f:
    let
      rs = builtins.mapAttrs f m;
      bad = firstRefusal (builtins.attrValues rs);
    in
    if bad != null then bad else ok (builtins.mapAttrs (_: r: r.right) rs);

  # ── the InertValue walk (BodyTerm §2.10b), unchanged ──
  inertBudget = {
    maxDepth = 32;
    maxNodes = 10000;
  };
  stop = nodes: refusal: {
    ok = false;
    inherit nodes refusal;
  };
  walkInert =
    path: depth: nodesLeft: v:
    let
      forced = builtins.tryEval (builtins.typeOf v);
      t = forced.value;
      drv =
        if t == "set" then
          builtins.tryEval ((v.type or null) == "derivation")
        else
          {
            success = true;
            value = false;
          };
    in
    if !forced.success then
      stop nodesLeft (
        refuse "lit-payload-throws" {
          inherit path;
          message = null;
        }
      )
    else if t == "lambda" then
      stop nodesLeft (refuse "lit-payload-function" { inherit path; })
    else if !drv.success then
      stop nodesLeft (
        refuse "lit-payload-throws" {
          path = path ++ [ "type" ];
          message = null;
        }
      )
    else if drv.value then
      stop nodesLeft (
        refuse "lit-payload-derivation" {
          inherit path;
          isDerivation = true;
        }
      )
    else if depth >= inertBudget.maxDepth then
      stop nodesLeft (
        refuse "lit-payload-budget" {
          inherit path;
          axis = "depth";
          budget = inertBudget;
        }
      )
    else if nodesLeft <= 0 then
      stop nodesLeft (
        refuse "lit-payload-budget" {
          inherit path;
          axis = "nodes";
          budget = inertBudget;
        }
      )
    else if t == "set" then
      walkMany path (depth + 1) (nodesLeft - 1) (
        map (n: {
          key = n;
          value = v.${n};
        }) (builtins.attrNames v)
      )
    else if t == "list" then
      walkMany path (depth + 1) (nodesLeft - 1) (
        builtins.genList (i: {
          key = toString i;
          value = builtins.elemAt v i;
        }) (builtins.length v)
      )
    else
      {
        ok = true;
        refusal = null;
        nodes = nodesLeft - 1;
      };
  walkMany =
    path: depth: nodesLeft: entries:
    builtins.foldl'
      (acc: e: if !acc.ok then acc else walkInert (path ++ [ e.key ]) depth acc.nodes e.value)
      {
        ok = true;
        refusal = null;
        nodes = nodesLeft;
      }
      entries;
  checkInert =
    v:
    let
      r = walkInert [ ] 0 inertBudget.maxNodes v;
    in
    if r.ok then null else r.refusal;

  # ── identity: one mint per node, Merkle over the children's digests ──
  childFields = {
    If = [
      "cond"
      "then_"
      "else_"
    ];
    Attrs = [ "attrs" ];
    List = [ "items" ];
    Concat = [ "items" ];
    PathJoin = [
      "head"
      "segments"
    ];
    Apply = [ "operands" ];
    All = [ "items" ];
    Any = [ "items" ];
    Not = [ "operand" ];
    Default = [ "fallback" ];
  };
  # A child term enters as its digest. A non-term child of `Attrs` can only be well-formed as a module
  # slot payload (a module: an attrset, a path or a function), and enters as a fixed tag, its payload
  # outside the mint (ADR-0034 `den-hoag-a0gc`). Any other non-term child is ill-formed and makes the
  # term unmintable, so two ill-formed terms never share an identity.
  slotShaped = v: builtins.isFunction v || builtins.isPath v || (builtins.isAttrs v && !(isTerm v));
  encodeChild =
    c:
    if isTerm c then
      let
        i = c.__mint;
      in
      if i ? minted then { term = i.minted; } else throw "term: a child term has no identity"
    else if builtins.isList c then
      map encodeChild c
    else if builtins.isAttrs c then
      builtins.mapAttrs (
        _: x:
        if isTerm x then
          encodeChild x
        else if slotShaped x then
          { moduleSlot = true; }
        else
          throw "term: an ill-formed Attrs child"
      ) c
    else
      throw "term: unencodable child";
  mintNode =
    former: fields:
    let
      enc = builtins.mapAttrs (
        n: v: if elem n (childFields.${former} or [ ]) then encodeChild v else v
      ) fields;
      attempt = builtins.tryEval (
        hashIdentity "term" [ "revision" "former" "fields" ] (
          l:
          {
            inherit revision former;
            fields = enc;
          }
          .${l}
        )
      );
    in
    if hashIdentity == null then
      {
        unmintable = "term: this ${former} term was built by an instance with no minting authority (hashIdentity = null); it has no identity (ADR-0034, REFUSED)";
      }
    else if attempt.success then
      { minted = attempt.value; }
    else
      {
        unmintable = "term: the mint refuses this ${former} term (a path, an out-of-range float, an ill-formed child, or a child with no identity); it has no identity (ADR-0034, REFUSED)";
      };
  mk =
    former: fields:
    fields
    // {
      __bodyTerm = former;
      __mint = mintNode former fields;
    };

  # ── the closed primitive table (BodyTerm §2.10), unchanged ──
  prims = {
    toString = {
      arity = 1;
      types = [ "scalar" ];
      storeCopies = false;
    };
    concatStringsSep = {
      arity = 2;
      types = [
        "string"
        "listOfString"
      ];
      storeCopies = true;
    };
    length = {
      arity = 1;
      types = [ "list" ];
      storeCopies = false;
    };
    attrNames = {
      arity = 1;
      types = [ "set" ];
      storeCopies = false;
    };
    elemAt = {
      arity = 2;
      types = [
        "list"
        "int"
      ];
      storeCopies = false;
    };
    getAttr = {
      arity = 2;
      types = [
        "name"
        "set"
      ];
      storeCopies = false;
    };
  };
  scalarTypes = [
    "string"
    "int"
    "float"
    "bool"
    "path"
    "null"
  ];
  hasType =
    want: v:
    if want == "scalar" then
      elem (builtins.typeOf v) scalarTypes
    else if want == "string" || want == "name" then
      builtins.isString v
    else if want == "listOfString" then
      builtins.isList v && builtins.all builtins.isString v
    else if want == "list" then
      builtins.isList v
    else if want == "set" then
      builtins.isAttrs v
    else if want == "int" then
      builtins.isInt v
    else
      false;
  reachesPath = v: builtins.isPath v || (builtins.isList v && builtins.any builtins.isPath v);
  isPrim = p: builtins.isString p && prims ? ${p};

  isNameList = p: builtins.isList p && builtins.all builtins.isString p;
  operandType =
    former: expected: got:
    refuse "former-operand-type" { inherit former expected got; };

  # ── the formers ──
  term = {
    lit =
      value:
      let
        bad = checkInert value;
      in
      if bad != null then bad else mk "Lit" { inherit value; };
    # The head is a SEPARATE argument, so an empty reference is not constructible.
    readCtx =
      head: path:
      if builtins.isString head && isNameList path then
        mk "ReadCtx" { inherit head path; }
      else
        operandType "readCtx" "a name and a list of names" [
          (builtins.typeOf head)
          (builtins.typeOf path)
        ];
    readFrom =
      target: path:
      if builtins.isString target && isNameList path then
        mk "ReadFrom" { inherit target path; }
      else
        operandType "readFrom" "a target name and a list of names" [
          (builtins.typeOf target)
          (builtins.typeOf path)
        ];
    default =
      head: path: fallback:
      if builtins.isString head && isNameList path then
        guard [ fallback ] (mk "Default" { inherit head path fallback; })
      else
        operandType "default" "a name and a list of names" [
          (builtins.typeOf head)
          (builtins.typeOf path)
        ];
    ref =
      id:
      if builtins.isString id then
        mk "Ref" { inherit id; }
      else
        refuse "ref-not-identifier" {
          got = builtins.typeOf id;
          remedy = "the core takes an identifier; a declaration resolves to one through the consumer vocabulary's resolver";
        };
    attrs = m: guard (builtins.attrValues m) (mk "Attrs" { attrs = m; });
    list = xs: guard xs (mk "List" { items = xs; });
    concat = xs: guard xs (mk "Concat" { items = xs; });
    pathJoin = head: segments: guard ([ head ] ++ segments) (mk "PathJoin" { inherit head segments; });
    apply =
      prim: operands:
      if builtins.isString prim then
        guard operands (mk "Apply" { inherit prim operands; })
      else
        operandType "apply" "a primitive name" (builtins.typeOf prim);
    ifThenElse =
      cond: then_: else_:
      guard [ cond then_ else_ ] (mk "If" { inherit cond then_ else_; });
    has =
      name:
      if builtins.isString name then
        mk "Has" { inherit name; }
      else
        operandType "has" "a name" (builtins.typeOf name);
    eq =
      path: value:
      if !(isNameList path) || path == [ ] then
        operandType "eq" "a non-empty list of names" (builtins.typeOf path)
      else
        let
          bad = checkInert value;
        in
        if bad != null then bad else mk "Eq" { inherit path value; };
    all = xs: guard xs (mk "All" { items = xs; });
    any = xs: guard xs (mk "Any" { items = xs; });
    always = mk "Always" { };
    not = x: guard [ x ] (mk "Not" { operand = x; });
  };

  knownFormers = [
    "Lit"
    "ReadFrom"
    "ReadCtx"
    "If"
    "Attrs"
    "List"
    "Concat"
    "PathJoin"
    "Apply"
    "Default"
    "Ref"
    "Has"
    "Eq"
    "All"
    "Any"
    "Always"
    "Not"
  ];
  conditionFormers = [
    "Has"
    "Eq"
    "All"
    "Any"
    "Always"
    "Not"
  ];
  contextReaders = [
    "ReadCtx"
    "Default"
    "Has"
    "Eq"
  ];

  children =
    t:
    let
      f = t.__bodyTerm;
    in
    if f == "If" then
      [
        t.cond
        t.then_
        t.else_
      ]
    else if f == "Attrs" then
      builtins.filter isTerm (builtins.attrValues t.attrs)
    else if f == "List" || f == "Concat" || f == "All" || f == "Any" then
      t.items
    else if f == "PathJoin" then
      [ t.head ] ++ t.segments
    else if f == "Apply" then
      t.operands
    else if f == "Not" then
      [ t.operand ]
    else if f == "Default" then
      [ t.fallback ]
    else
      [ ];

  # The context names a term reads: every former that reads the context, at any depth, each once.
  headOf =
    t:
    if t.__bodyTerm == "Eq" then
      builtins.head t.path
    else if t.__bodyTerm == "Has" then
      t.name
    else
      t.head;
  readCtxHeads =
    t:
    if !(isTerm t) then
      [ ]
    else
      unique (
        (if elem t.__bodyTerm contextReaders then [ (headOf t) ] else [ ])
        ++ builtins.concatMap readCtxHeads (children t)
      );

  # ── declaration-time checks ──
  undeclared =
    declared: name:
    refuse "undeclared-name" {
      inherit name declared;
      message = "'${name}' is not a declared coordinate; did you mean one of: ${builtins.concatStringsSep ", " declared}";
    };

  # instance = { vocabulary ? knownFormers; declared ? null; slots ? null; }
  # slots = { isKey = name -> bool; admits = value -> bool; }
  checkTerm =
    instance: t:
    let
      vocabulary = instance.vocabulary or knownFormers;
      declared = instance.declared or null;
      slots = instance.slots or null;
      recurse = checkTerm instance;
      attrChild =
        k: v:
        if isTerm v || isRefusal v then
          recurse v
        else if slots != null && slots.isKey k then
          (
            if slots.admits v then
              ok v
            else
              refuse "module-slot-refused" {
                key = k;
                got = builtins.typeOf v;
              }
          )
        else if builtins.isFunction v then
          refuse "term-function" {
            key = k;
            remedy = "a function is admitted only in a declared module slot; write a term, or declare the closure through the framework's surface";
          }
        else
          refuse "term-vocabulary" {
            key = k;
            node = builtins.typeOf v;
            inherit vocabulary;
          };
    in
    if isRefusal t then
      t
    else if !(isTerm t) then
      (
        if builtins.isFunction t then
          refuse "term-function" { remedy = "a closure is not a term"; }
        else
          refuse "term-vocabulary" {
            node = builtins.typeOf t;
            inherit vocabulary;
          }
      )
    else if !(elem t.__bodyTerm vocabulary) then
      refuse "term-vocabulary" {
        former = t.__bodyTerm;
        inherit vocabulary;
      }
    else if t.__bodyTerm == "Apply" && !(isPrim (t.prim or null)) then
      refuse "term-vocabulary" {
        prim = if builtins.isString (t.prim or null) then t.prim else builtins.typeOf (t.prim or null);
        vocabulary = builtins.attrNames prims;
      }
    else if declared != null && elem t.__bodyTerm contextReaders && !(elem (headOf t) declared) then
      undeclared declared (headOf t)
    else if t.__bodyTerm == "Attrs" then
      let
        r = traverseAttrs t.attrs attrChild;
      in
      if isRefusal r then r else ok t
    else
      let
        bad = firstRefusal (map recurse (children t));
      in
      if bad != null then bad else ok t;

  # The names a condition COVERS (Apt-Blair-Walker's positive literals). A disjunction covers only
  # what every disjunct covers; `not`, `always` and an empty `any` cover nothing.
  cover =
    c:
    let
      f = c.__bodyTerm;
    in
    if f == "Has" || f == "Eq" then
      [ (headOf c) ]
    else if f == "All" then
      unique (builtins.concatMap cover c.items)
    else if f == "Any" then
      (
        if c.items == [ ] then
          [ ]
        else
          builtins.foldl' (acc: x: builtins.filter (n: elem n (cover x)) acc) (cover (
            builtins.head c.items
          )) (builtins.tail c.items)
      )
    else
      [ ];
  # The reads the safety clause governs: the value reads that can fail on absence. A `ref`'s reads are
  # the door's declared reads and the check does not reach them (Q1's stated price).
  safetyReads =
    t:
    if !(isTerm t) then
      [ ]
    else if t.__bodyTerm == "ReadCtx" || t.__bodyTerm == "Default" then
      [
        {
          inherit (t) head path;
          former = t.__bodyTerm;
        }
      ]
      ++ builtins.concatMap safetyReads (children t)
    else
      builtins.concatMap safetyReads (children t);
  notCondition =
    c:
    if !(isTerm c) then
      { former = builtins.typeOf c; }
    else if !(elem c.__bodyTerm conditionFormers) then
      { former = c.__bodyTerm; }
    else
      builtins.foldl' (acc: x: if acc != null then acc else notCondition x) null (children c);

  checkClause =
    instance: clause:
    let
      missing =
        if builtins.isAttrs clause then
          builtins.filter (f: !(clause ? ${f})) [
            "condition"
            "body"
          ]
        else
          [
            "condition"
            "body"
          ];
      c = checkTerm instance clause.condition;
      b = checkTerm instance clause.body;
      bad = notCondition clause.condition;
      covered = cover clause.condition;
      uncovered = builtins.filter (r: !(elem r.head covered)) (safetyReads clause.body);
    in
    if missing != [ ] then
      refuse "declaration-missing-field" {
        object = "clause";
        fields = missing;
        got = builtins.typeOf clause;
      }
    else if isRefusal c then
      c
    else if bad != null then
      refuse "condition-former" {
        inherit (bad) former;
        conditionVocabulary = conditionFormers;
      }
    else if isRefusal b then
      b
    else if uncovered != [ ] then
      refuse "unsafe-read" {
        inherit uncovered covered;
        message = "the body reads ${
          builtins.concatStringsSep ", " (unique (map (r: "'${r.head}'") uncovered))
        } with no positive atom of the condition covering it; add `has <name>` (or an `eq` over it) to the condition";
      }
    else
      ok clause;

  # ── resolution ──
  # env = { context ? { }; declared ? null; ref ? null; targets ? { }; }
  walk =
    value: path:
    builtins.foldl'
      (
        acc: seg:
        if acc.found && builtins.isAttrs acc.value && acc.value ? ${seg} then
          {
            found = true;
            value = acc.value.${seg};
          }
        else
          {
            found = false;
            value = null;
          }
      )
      {
        found = true;
        inherit value;
      }
      path;
  # BodyTerm's projection, witness unchanged: the first missing segment is named.
  project =
    origin: value: path:
    builtins.foldl' (
      acc: seg:
      if isRefusal acc then
        acc
      else if !(builtins.isAttrs acc.right) || !(acc.right ? ${seg}) then
        refuse "projection-path-missing" {
          inherit origin path;
          missing = seg;
        }
      else
        ok acc.right.${seg}
    ) (ok value) path;
  pathComponents = seg: builtins.filter builtins.isString (builtins.split "/" seg);

  resolveTerm =
    env: t:
    let
      context = env.context or { };
      declared = env.declared or null;
      recurse = resolveTerm env;
      undecl = n: declared != null && !(elem n declared);
      bool =
        former: r:
        if isRefusal r then
          r
        else if builtins.isBool r.right then
          r
        else
          refuse "former-operand-type" {
            inherit former;
            expected = "bool";
            got = builtins.typeOf r.right;
          };
      # Short-circuit, left to right: under a declared set no checked atom refuses, so the order cannot
      # matter there; under the open world a refusing `has` keeps today's R.
      scan =
        former: stopOn: items:
        builtins.foldl' (
          acc: x: if isRefusal acc || acc.right == stopOn then acc else bool former (recurse x)
        ) (ok (!stopOn)) items;
      f = t.__bodyTerm;
    in
    if isRefusal t then
      t
    else if !(isTerm t) then
      refuse "term-vocabulary" {
        node = builtins.typeOf t;
        vocabulary = knownFormers;
      }
    else if f == "Lit" then
      ok t.value
    else if f == "ReadCtx" || f == "Default" then
      if undecl t.head then
        undeclared declared t.head
      else if !(context ? ${t.head}) then
        refuse "read-absent" {
          inherit (t) head;
          available = builtins.attrNames context;
        }
      else if f == "ReadCtx" then
        project { readCtx = t.head; } context.${t.head} t.path
      else
        let
          w = walk context.${t.head} t.path;
        in
        if w.found then ok w.value else recurse t.fallback
    else if f == "ReadFrom" then
      let
        targets = env.targets or { };
      in
      if !(targets ? ${t.target}) then
        refuse "readfrom-names-non-member" {
          inherit (t) target;
          available = builtins.attrNames targets;
        }
      else
        project { readFrom = t.target; } targets.${t.target} t.path
    else if f == "Ref" then
      if (env.ref or null) == null then
        refuse "ref-unresolved" { inherit (t) id; }
      else
        let
          r = env.ref t.id;
        in
        if isRefusal r || (builtins.isAttrs r && builtins.attrNames r == [ "right" ]) then
          r
        else
          refuse "ref-result-shape" { inherit (t) id; }
    else if f == "Has" then
      if undecl t.name then
        undeclared declared t.name
      else if context ? ${t.name} then
        ok true
      else if declared == null then
        refuse "absent-coordinate" { inherit (t) name; }
      else
        ok false
    else if f == "Eq" then
      let
        h = builtins.head t.path;
      in
      if undecl h then
        undeclared declared h
      else
        let
          w = walk context t.path;
        in
        ok (w.found && w.value == t.value)
    else if f == "Always" then
      ok true
    else if f == "Not" then
      let
        r = bool "not" (recurse t.operand);
      in
      if isRefusal r then r else ok (!r.right)
    else if f == "All" then
      scan "all" false t.items
    else if f == "Any" then
      scan "any" true t.items
    else if f == "If" then
      let
        d = decideIf env t;
      in
      if isRefusal d then d else recurse d.right
    else if f == "Attrs" then
      traverseAttrs t.attrs (_: v: if isTerm v then recurse v else ok v)
    else if f == "List" then
      traverse t.items recurse
    else if f == "Concat" then
      let
        r = traverse t.items recurse;
      in
      if isRefusal r then
        r
      else if builtins.any builtins.isPath r.right then
        refuse "path-operand-store-copying-former" {
          former = "Concat";
          operands = map builtins.typeOf r.right;
        }
      else if !(builtins.all builtins.isString r.right) then
        refuse "former-operand-type" {
          former = "Concat";
          expected = "string";
          got = map builtins.typeOf r.right;
        }
      else
        ok (builtins.concatStringsSep "" r.right)
    else if f == "PathJoin" then
      let
        h = recurse t.head;
        segs = traverse t.segments recurse;
        escaping = builtins.filter (s: elem ".." (pathComponents s)) segs.right;
      in
      if isRefusal h then
        h
      else if isRefusal segs then
        segs
      else if !(builtins.isPath h.right) then
        refuse "pathjoin-operand" {
          position = "head";
          expected = "path";
          got = builtins.typeOf h.right;
        }
      else if !(builtins.all builtins.isString segs.right) then
        refuse "pathjoin-operand" {
          position = "segment";
          expected = "string";
          got = map builtins.typeOf segs.right;
        }
      else if escaping != [ ] then
        refuse "pathjoin-operand" {
          position = "segment";
          reason = "parent-directory-component";
          segments = escaping;
        }
      else
        ok (builtins.foldl' (acc: seg: acc + ("/" + seg)) h.right segs.right)
    else
      # Apply
      let
        spec = if isPrim t.prim then prims.${t.prim} else null;
      in
      if spec == null then
        refuse "term-vocabulary" {
          prim = if builtins.isString t.prim then t.prim else builtins.typeOf t.prim;
          vocabulary = builtins.attrNames prims;
        }
      else if builtins.length t.operands != spec.arity then
        refuse "apply-arity-or-type" {
          prim = t.prim;
          expectedArity = spec.arity;
          got = builtins.length t.operands;
        }
      else
        let
          r = traverse t.operands recurse;
          vs = r.right;
          a = builtins.elemAt vs 0;
          b = if builtins.length vs > 1 then builtins.elemAt vs 1 else null;
          badTypeIndex = findFirst (
            i: !(hasType (builtins.elemAt spec.types i) (builtins.elemAt vs i))
          ) null (builtins.genList (i: i) spec.arity);
        in
        if isRefusal r then
          r
        # The store-copy predicate runs FIRST for a ⊗ former: a path operand is refused as a
        # store-copying coercion, never reported as a mere type mismatch.
        else if spec.storeCopies && builtins.filter reachesPath vs != [ ] then
          refuse "path-operand-store-copying-former" {
            prim = t.prim;
            operands = map builtins.typeOf vs;
          }
        else if badTypeIndex != null then
          refuse "apply-arity-or-type" {
            prim = t.prim;
            position = badTypeIndex;
            expected = builtins.elemAt spec.types badTypeIndex;
            got = builtins.typeOf (builtins.elemAt vs badTypeIndex);
          }
        else if t.prim == "toString" then
          ok (builtins.toString a)
        else if t.prim == "concatStringsSep" then
          ok (builtins.concatStringsSep a b)
        else if t.prim == "length" then
          ok (builtins.length a)
        else if t.prim == "attrNames" then
          ok (builtins.attrNames a)
        else if t.prim == "elemAt" then
          (
            if b < 0 || b >= builtins.length a then
              refuse "apply-domain" {
                prim = "elemAt";
                index = b;
                length = builtins.length a;
              }
            else
              ok (builtins.elemAt a b)
          )
        else if !(b ? ${a}) then
          refuse "apply-domain" {
            prim = "getAttr";
            name = a;
            available = builtins.attrNames b;
          }
        else
          ok b.${a};

  # An `If`'s chosen branch, as a term: its condition resolved and checked to be a bool. Shared by
  # `resolveTerm` and `resolveFields`, so the condition's semantics are stated once.
  decideIf =
    env: t:
    let
      c = resolveTerm env t.cond;
    in
    if isRefusal c then
      c
    else if !(builtins.isBool c.right) then
      refuse "former-operand-type" {
        former = "If";
        position = "cond";
        expected = "bool";
        got = builtins.typeOf c.right;
      }
    else
      ok (if c.right then t.then_ else t.else_);

  # `resolveTerm`'s value with each field resolved where it is READ (ADR-0010 §4(a) clause 3, van
  # Antwerpen 2018 §2.5: a delayed substitution is applied to a field once it is accessed). `Attrs`,
  # `List` and a decided `If` are descended structurally; every other former is a leaf and resolves
  # whole through `resolveTerm`. A refusal is not returned: it is handed to `onLeft path left` at the
  # read of its field, `path` the attribute names and list indices from the root. `resolveTerm` keeps
  # its total `Either`, so a caller reading `right` still reads a fully resolved value.
  resolveFields =
    env: onLeft: t:
    let
      go =
        p: x:
        if isRefusal x then
          onLeft p x.left
        else if isTerm x && x.__bodyTerm == "Attrs" then
          builtins.mapAttrs (k: v: if isTerm v then go (p ++ [ k ]) v else v) x.attrs
        else if isTerm x && x.__bodyTerm == "List" then
          builtins.genList (i: go (p ++ [ i ]) (builtins.elemAt x.items i)) (builtins.length x.items)
        else if isTerm x && x.__bodyTerm == "If" then
          let
            d = decideIf env x;
          in
          if isRefusal d then onLeft p d.left else go p d.right
        else
          let
            r = resolveTerm env x;
          in
          if isRefusal r then onLeft p r.left else r.right;
    in
    go [ ] t;

  # ── the registration identifier `ref` carries (unifying spec §2.8): `builtins.toJSON` over a FIXED
  # field domain. toJSON alone is not injective: a record carrying `outPath` or `__toString` encodes as
  # that string, so two records differing beside it encode equal, and a path is copied into the store.
  # Every field is checked first, so within the domain equal strings are equal records, and anything
  # outside it is refused by name.
  refIdFields = {
    declared = {
      site = "name";
      reads = "reads";
    };
    nested = {
      outer = "name";
      sources = "sources";
      position = "position";
      reads = "reads";
    };
  };
  plainString = v: builtins.isString v && !(builtins.hasContext v);
  isSourceIdentity = v: plainString v && builtins.match "[^:]+:[0-9a-f]{64}" v != null;
  inDomain =
    want: v:
    if want == "name" then
      plainString v
    else if want == "reads" then
      v == null || (builtins.isList v && builtins.all plainString v)
    else if want == "position" then
      builtins.isList v && builtins.all (s: plainString s || builtins.isInt s) v
    else
      builtins.isAttrs v
      && !(v ? outPath || v ? __toString)
      && builtins.all isSourceIdentity (builtins.attrValues v);
  domainRefusal =
    field: expected: v:
    refuse "ref-id-domain" {
      inherit field expected;
      got = builtins.typeOf v;
      message =
        if builtins.isPath v then
          "a registration identifier field holds a path, which toJSON would copy into the store; pass its string form"
        else
          "a registration identifier field is outside its domain (${expected})";
    };
  refId =
    r:
    let
      kind =
        if builtins.isAttrs r && builtins.length (builtins.attrNames r) == 1 then
          builtins.head (builtins.attrNames r)
        else
          null;
      want = if kind == null then null else refIdFields.${kind} or null;
      body = r.${kind};
      bad = builtins.filter (n: !(inDomain want.${n} body.${n})) (builtins.attrNames want);
    in
    if want == null then
      domainRefusal [ ] "a record with one key, declared or nested" r
    else if
      !(builtins.isAttrs body)
      || body ? outPath
      || body ? __toString
      || builtins.attrNames body != builtins.attrNames want
    then
      domainRefusal [ kind ]
        "a record with exactly the fields ${builtins.concatStringsSep ", " (builtins.attrNames want)}"
        body
    else if bad != [ ] then
      let
        n = builtins.head bad;
      in
      domainRefusal [ kind n ] want.${n} body.${n}
    else
      ok (builtins.toJSON r);
in
{
  inherit
    term
    knownFormers
    prims
    inertBudget
    checkInert
    isTerm
    children
    readCtxHeads
    checkTerm
    checkClause
    resolveTerm
    resolveFields
    refId
    ;
}
