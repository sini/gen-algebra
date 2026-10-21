# Palmer §2.2-2.3: intensional functions, their identity regime, and conservative equality.
#
# ★ THE CONSTRUCTOR IS AN ENCODER, NOT A RECORD BUILDER, and that is the whole of this file's
# design. Palmer's Def 5.5 fixes a function's closure as the canonicalised free variables of its
# body; Def 5.6 requires that every recorded closure IS that canonical closure and that two
# functions sharing a program point differ only by substitution; Def 5.7(3) requires an initial
# program to have no two functions at one program point. Palmer discharges all of it BY
# CONSTRUCTION AT AN ENCODER and never by a check — his higher-level language "only requires (and
# only permits) the programmer to specify F", and the encoding establishes the program points and
# environments.
#
# The shipped constructor inverted both halves: it took the NAME from the caller, so two bodies
# could share one program point, and the CLOSURE from the caller, which Palmer explicitly
# forecloses. What it held was A record a caller passed, not THE canonical closure — so an
# under-complete closure was undetectable, and a comparison built on it merged behaviourally
# distinct functions.
#
# Here the closure stops being a caller argument. A construction is named by a CONSTRUCTOR and an
# INERT ARGUMENT VALUE against a registry that builds the function, so an under-complete closure is
# INEXPRESSIBLE rather than undetected: there is no closure argument left to under-supply. The
# author specifies `(ctor, args)` and nothing else — Palmer's encoder, transposed.
#
# ★ THE MINT IS INJECTED, AND THE INJECTION IS LOAD-BEARING. `hashIdentity` is the substrate's
# single minting authority and it lives downstream of this library, so importing it would close a
# flake dependency cycle. Taking it as a PARAMETER mints inside the eval doing the constructing — the
# consumer's own — so the identity is OWNED rather than borrowed and no second minting authority is
# introduced. gen-algebra keeps its zero-dependency property: nothing is imported here, the authority
# arrives as an argument. The encoder below takes it and mints nothing (its values are compared, see
# `__mint` there); `preimageTagOf` and `componentsPreimage` mint with it.
let
  # ── the identity regime ──
  #
  # The ONE access discipline over the three identity regimes, and it is TOTAL OVER THOSE THREE
  # REGIMES — not over the two populations of the migration window, which is the narrower claim it
  # replaced and which omits the sealed regime entirely. `__mint` is a TAGGED SUM, so no reader may
  # branch on FIELD PRESENCE and then read `.minted` raw: on a value that has no mintable identity
  # `v ? __mint` holds and `.minted` is absent, and that read aborts uncatchably rather than
  # refusing.
  #
  #   minted     — an identity over a preimage total in the value's distinguishing content, so the
  #                key it yields is EXACT.
  #   unmintable — no identity and no substitute; the key it yields is a BUCKET label.
  #   unmigrated — the migration window: no producer has stamped this value, so the shipped
  #                program-point name is the bucket label.
  #
  # This discipline lives HERE, with the constructor that emits the tag, and any key site reads it
  # from here rather than keeping its own copy: one tagged sum with two readers is how the two stop
  # agreeing. This library's own key site, the `search` runner's continuation dedup, was retired
  # under ADR-0008 §1 (den-hoag-b7u1v); the discipline and its obligations stay with the tag.
  #
  # ★ THAT CONSOLIDATION IS REPO-LOCAL, AND CLAIMING MORE WOULD OVERSTATE IT. gen-types and
  # gen-dispatch keep definitions of their own; gen-types takes this library as an input (the mint is
  # the gen-identity leaf, so the edge closes no cycle) and builds its per-component identity on
  # `componentsPreimage` and `sealedCollisionEq` below, while its `identityOf` keeps the arms only a
  # type record has (a rewritten `check`, a foreign record).
  # ★ A MARK BESIDE SEALED COMPONENTS IS NOT AN EXACT IDENTITY. A value carrying a non-empty
  # `__sealed` (a gen-types type or a gen-schema kind over a caller lambda or a registered
  # construction) mints over the rest and is blind to what it sealed, so it is on the compared arm
  # here: `isExact` is false, its mark is a BUCKET LABEL and never a key, and `conservativeEq`
  # decides it over the mark AND the sealed subjects. `preimageTagOf` still enters it by its mark,
  # for propagation.
  hasMark = v: v ? __mint && v.__mint ? minted;

  # ★ A MARK IS NOT AN IDENTITY, AND IT HAS ITS OWN TWO READERS. Beside sealed components the mark
  # is a BUCKET LABEL (`isExact` false): a site may bucket or look up by it, and decides within the
  # bucket over the sealed subjects with `sealedCollisionEq` (gen-schema's `kindEq`, gen-select's
  # `kindEq` over its kind key). A mark alone never decides an equal-mark pair. Such a site needs
  # the mark wherever one was minted, sealed components or not, and `identityOf` answers the
  # compared arm for exactly the sealed half. gen-scope's `requireScope` and `sameKind` are such
  # sites: they decide within the bucket by `sealedCollisionEq`, through gen-scope's `sameKindValue`.
  # `hasMark` is the DECISION (does the value carry one; it forces the `__mint` record and
  # never the digest), `markOf` the DEMAND, which refuses by name where `.minted` raw would abort
  # uncatchably. Where nothing is sealed the two agree: `identityOf v` is `{ minted = markOf v; }`.
  # Both are written so a read costs no thunk and `markOf` no second call: `?` and `or` answer
  # false and the default on a non-set, so neither needs an `isAttrs` guard.
  markOf =
    v:
    v.__mint.minted
      or (throw "gen-algebra: markOf: the value carries no mark (no `__mint` with a `minted` arm); a ${builtins.typeOf v} is not a value its producer minted. Decide with `hasMark` before demanding the mark.");
  sealsSomething = v: builtins.isAttrs (v.__sealed or null) && v.__sealed != { };

  # ── the witness declaration: is the mark still a claim about THIS value? ──
  #
  # A mark is minted over the value its producer COMPLETED, and Nix `//` copies every slot it does
  # not override, the mark included. So whether a carried mark still states the value's content is
  # ADR-0034's minted condition read at DECISION time, and only the producer knows which of its
  # fields witness it. A producer declares them in `__witness`, by field name, so this library reads
  # the witnesses without knowing any vocabulary's spelling:
  #
  #   completion = "<field>"   the field holding `_: <the completed value>` (Bracha & Cook 1990 §2:
  #                            a `//` copies the witness unchanged, so the copy's witness still
  #                            returns the original). A value departing from it is REFUSED by name.
  #   checks = { <field> = "<witness field>"; }
  #                            a field published beside a witness holding the value the mark was
  #                            minted over. A value whose field no longer holds its witness (a
  #                            wrapper rewrote it) keeps its mark as a bucket label and is COMPARED.
  #
  # A value declaring nothing reads as before. A MARKED value's declaration names its `completion`:
  # the mark's claim is checkable only through it, so a declaration without one, or naming a field the
  # value does not carry as a function, is refused by name, never read as `holds` (otherwise a `//`
  # that re-declares the witness would forge the stamp it guards). A declaration that is not a record
  # of field names is refused by name too, so no shape of it reaches an uncatchable type error. A
  # well-formed declaration is data, so it is inert under `==` and in every walker.
  nameOf = v: if builtins.isString (v.name or null) then v.name else "<unnamed>";
  declarationFault =
    v:
    let
      w = v.__witness;
    in
    if !(v ? __witness) then
      # a declared subject is a claim only its producer's completion can check, so a value carrying
      # one without the witness is refused, never read as an undeclared record
      if declaresSubject v then
        "it declares a comparison subject and no `__witness`, so its subject's claim cannot be checked"
      else
        null
    else if !(builtins.isAttrs w) then
      "its `__witness` is a ${builtins.typeOf w}, not a record of field names"
    else if w ? completion && !(builtins.isString w.completion) then
      "its `__witness.completion` is a ${builtins.typeOf w.completion}, not a field name"
    else if
      w ? checks
      && !(builtins.isAttrs w.checks && builtins.all builtins.isString (builtins.attrValues w.checks))
    then
      "its `__witness.checks` is not a record of field names"
    else if hasMark v && !(w ? completion) then
      "its `__witness` declares no `completion`, so its mark's claim cannot be checked"
    else if !(w ? completion) && declaresSubject v then
      "its `__witness` declares no `completion`, so its subject's claim cannot be checked"
    else
      null;
  witnessOf =
    v:
    let
      fault = declarationFault v;
    in
    if fault == null then
      v.__witness or { }
    else
      throw "gen-algebra: identityOf: `${nameOf v}' carries a malformed witness declaration: ${fault}; its producer declares `__witness = { completion = \"<field>\"; checks = { <field> = \"<witness field>\"; }; }`";
  rewritesWitnessed =
    v:
    let
      cs = (witnessOf v).checks or { };
    in
    builtins.any (n: v ? ${n} && v ? ${cs.${n}} && v.${n} != v.${cs.${n}}) (builtins.attrNames cs);
  # The stamp's decision: the completed value against the operand under `==`, descending through
  # one-key slices and singleton cells where `==` throws (a shared throwing thunk is forced before the
  # identity check on upstream Nix and Determinate and not on Lix). Two cells that both have no WHNF
  # value agree.
  stampAgrees =
    let
      defined = v: (builtins.tryEval (builtins.seq v true)).success;
      cellAgrees =
        ca: cb: va: vb:
        let
          r = builtins.tryEval (ca == cb);
          da = defined va;
          db = defined vb;
        in
        if r.success then
          r.value
        else if da && db then
          descend va vb
        else
          !da && !db;
      descend =
        a: b:
        if builtins.isAttrs a && builtins.isAttrs b then
          let
            names = builtins.attrNames a;
            slice = n: builtins.intersectAttrs { ${n} = null; };
          in
          names == builtins.attrNames b
          && builtins.all (n: cellAgrees (slice n a) (slice n b) a.${n} b.${n}) names
        else if builtins.isList a && builtins.isList b then
          let
            ca = map (v: [ v ]) a;
            cb = map (v: [ v ]) b;
          in
          builtins.length a == builtins.length b
          && builtins.all (
            i:
            cellAgrees (builtins.elemAt ca i) (builtins.elemAt cb i) (builtins.elemAt a i) (builtins.elemAt b i)
          ) (builtins.genList (i: i) (builtins.length a))
        else
          false;
    in
    a: b: cellAgrees a b a b;
  # The verdict, a tagged sum with three arms: `holds`, `compared` (the mark is a bucket label) or
  # `refused` (the value is not the one its producer completed).
  standingOf =
    v:
    let
      fault = declarationFault v;
      declared = v ? __witness && v.__witness ? completion;
      f = v.__witness.completion;
    in
    if fault != null then
      { refused = "it carries a malformed witness declaration: ${fault}"; }
    else if declared && !(v ? ${f} && builtins.isFunction v.${f}) then
      {
        refused = "it declares its completion witness `${f}' and carries no function there, so its mark's claim cannot be checked";
      }
    else if declared && !(stampAgrees (v.${f} null) v) then
      { refused = "a `//` over it keeps its mark while changing what the mark stands for"; }
    else if rewritesWitnessed v then
      { compared = "a wrapper rewrote a field its mark was minted over"; }
    else
      { holds = true; };

  identityOf =
    v:
    if hasMark v && rewritesWitnessed v then
      {
        unmintable = {
          reason = "a wrapper rewrote a field its mark was minted over, so the mark no longer states its content";
        };
      }
    else if hasMark v && sealsSomething v then
      {
        unmintable = {
          reason = "a mark beside sealed components, which it is blind to, is not an exact identity";
        };
      }
    else if v ? __mint && v.__mint ? minted then
      { inherit (v.__mint) minted; }
    else if v ? __mint then
      { inherit (v.__mint) unmintable; }
    else
      { unmigrated = v.name; };

  # The one-character REGIME TAG an arm emits into a key space. Three arms writing into ONE untagged
  # string space is a forgery channel, and the encoder's own rule closes it the same way: tag every
  # node so forgery is INEXPRESSIBLE rather than unlikely. Without a tag a continuation merely NAMED
  # string-equal to another's minted digest lands on that digest's key and one of the two is
  # dropped; with the tag emitted before the payload an unmigrated arm can never render into the
  # minted arm's space at all.
  regimeTagOf =
    i:
    if i ? minted then
      "m"
    else if i ? unmintable then
      "s"
    else
      "u";

  # Whether an arm's key is EXACT — a dedup key — or a bucket label. Read off the same `identityOf`
  # result rather than by re-testing `__mint`, so the tagged sum has one reader and not two.
  #
  # ★ A NON-EXACT KEY OBLIGES ITS CONSUMER. A key site that dedups on a bucket label must store the
  # MEMBERS seen under each key (`key → [ members ]`) and decide membership by comparing
  # `comparisonSubject` of the whole value against the bucket's members; presence of the key decides
  # only on the exact (minted) arm. A boolean `seen` is not a bucket: there is nothing stored to
  # compare against, so a presence test over a bucket label keeps 1 of 2 behaviourally distinct
  # values (measured, closure-identity spec §2.7 site 4). The comparison's precision is an allocation
  # artefact, and a finer relation costs dedup and never correctness — only where the relation
  # merges WORK; a site whose relation decides an answer owes its own argument.
  isExact = i: i ? minted;

  # The comparison SUBJECT for the non-exact arms: the reified value itself, excluding nothing. A
  # value's fields are total data; the one partial operation, DEMANDING an identity, is gen-types'
  # `idOf`, a function, so no field of a compared value is an accessor that refuses when forced.
  #
  # ★ A DECLARED SUBJECT IS THE SUBJECT. A value carrying `__mint.unmintable.subject` (the encoder
  # below) names what its comparison compares, so that subject is answered instead of the record:
  # the record holds `fn`, a lambda rebuilt per construction, and comparing it would separate two
  # constructions of one term on an allocation fact.
  #
  # `__mint.minted` cannot refuse inside a comparison either: the minted and sealed arms live under
  # DIFFERENT KEY NAMES, and Nix `==` decides on the name set before forcing any value. Two sealed
  # values carry inert payloads under one name, so nothing forces there. The one path that does force
  # a mint is a minted-against-minted comparison, and that arm never reaches here: it compares digests.
  declaresSubject =
    v:
    builtins.isAttrs v
    && v ? __mint
    && builtins.isAttrs v.__mint
    && v.__mint ? unmintable
    && builtins.isAttrs v.__mint.unmintable
    && v.__mint.unmintable ? subject;
  hasDeclaredSubject = v: declaresSubject v && (standingOf v) ? holds;
  # ★ A DEPARTED CONSTRUCTION IS NOT AN UNDECLARED ONE. A reader that hands a declared subject on
  # (`componentsPreimage`, gen-types `memberSubject`) hands `entry` on while the value holds its
  # standing, and otherwise `entry` wrapped with the departure's reason, which `sealedCollisionEq`
  # reads: never the reified record, whose `==` can walk a back-edge uncatchably.
  subjectEntry =
    v: entry:
    let
      st = standingOf v;
    in
    if st ? holds then
      entry
    else
      {
        __departed = st.refused or st.compared;
        __subject = entry;
      };
  isDepartedEntry =
    v:
    let
      r = builtins.tryEval (builtins.isAttrs v && v ? __departed && v ? __subject);
    in
    r.success && r.value;
  #
  # ★ CLOSURES FIRST. Undeclared, the subject of a record is a two-element list: its function-valued
  # fields, then the whole record. List `==` decides index 0 before index 1, and `==` on two functions
  # answers without entering either closure, so two records whose closures differ decide `false`
  # before `==` walks an attribute that may hold a back-edge (a nixpkgs record's `functor.type` across
  # two lib instances recurses until the evaluator aborts uncatchably). The prefix is a sub-attrset of
  # the record holding the same slots, so this is still one `==` over the whole reified value.
  #
  # ★ AN ENUMERATED VALUE MOVE, NOT AN ABORT. Finding the function-valued fields forces EVERY field to
  # WHNF, inside `tryEval`, so a field that throws catchably is left out of the prefix and to the bare
  # `==` after it. What the bare `==` would have decided, this decides the same, with two exceptions:
  #   1. A derivation-shaped record (`type = "derivation"`): Nix `==` compares two of them by
  #      `outPath` alone, and the prefix compares their closures first, so it decides FINER (`false`
  #      where the bare `==` said `true`). ADR-0034 excludes every derivation from this relation.
  #   2. A field whose WHNF errors UNCATCHABLY propagates where the bare `==` would have decided on
  #      another attribute first: nixpkgs `lib` on Lix, whose `convertHash` names a builtin Lix
  #      lacks, aborts here (`conservativeEq lib lib` answers `true` under the bare `==`).
  # Where every closure slot is shared and the record's `==` reaches a back-edge before a
  # difference, it aborts as the bare `==` does. A record with no function-valued field keeps the
  # bare `==`.
  closuresOf =
    v:
    builtins.intersectAttrs (builtins.listToAttrs (
      map
        (n: {
          name = n;
          value = null;
        })
        (
          builtins.filter (
            n:
            let
              r = builtins.tryEval (builtins.isFunction v.${n});
            in
            r.success && r.value
          ) (builtins.attrNames v)
        )
    )) v;
  subjectAt =
    standing: v:
    if declaresSubject v && standing ? holds then
      v.__mint.unmintable.subject
    else if builtins.isAttrs v then
      [
        (closuresOf v)
        v
      ]
    else
      v;
  # A projection has no second operand, so a declared value that does not hold its standing has no
  # admissible answer: its stale subject is unsound and its record is the uncatchable arm.
  comparisonSubject =
    v:
    let
      st = standingOf v;
    in
    if !(declaresSubject v) then
      subjectAt { } v
    else if st ? holds then
      v.__mint.unmintable.subject
    else
      throw "gen-algebra: comparisonSubject: `${nameOf v}' is not the value its producer completed: ${st.refused or st.compared}; build the change through its producer";

  # ── per-component preimage tags (c+), den-hoag-markof-partial-preimage-znfjq ──
  #
  # A composite whose components sit on different ADR-0034 regimes stays MINTED: each component
  # enters its preimage as a TAG, "a sealed site gets no identity, a total tagged field", and the
  # limbs apply PER COMPONENT so one sealed component does not drag the composite onto the
  # comparison limb. (Not `regimeTagOf` above, which is the one-character KEY-SPACE tag; these
  # are PREIMAGE tags.) Four shapes, each a record under its own key so no shape can render into
  # another's:
  #
  #   { minted = <digest>; }  the component carries a minted identity (read through `identityOf`)
  #   { inert = <digest>; }   an inert value: the mint takes it whole
  #   { undefined = true; }   the value throws (catchably) at WHNF: it has no value to identify,
  #                           e.g. an option with no default at the kind level
  #   sealedMarker            anything else: a lambda, a path, a derivation, an unmintable or an
  #                           unmigrated value, a value past the encoder's bounds, and a value
  #                           defined at WHNF with a member that throws
  #
  # `undefined` is decided at WHNF, never under `deepSeq`: a value with SOME content (a record
  # with one throwing member, a package with a throwing passthru) is not valueless, and tagging
  # it `undefined` would drop the content it has. It goes to the mint, whose catchable refusal
  # seals it. `deepSeq` over a real package also recurses past the evaluator's call depth, an
  # abort `tryEval` cannot catch; the mint refuses the same package catchably.
  #
  # THE REGIME IS DECIDED BY THE MINT unless the constructor declares it: the encoder is total,
  # so handing it the value and reading the answer IS the classification (gen-types
  # `mkChecker`'s idiom). A component a constructor declares sealed is tagged without trying.
  # The mint is INJECTED, as `mkIntensional` takes it, so gen-algebra imports nothing.
  #
  # RESIDUE: forcing a value that aborts UNCATCHABLY (a missing attribute, a type error) aborts
  # here too. The mint forces its input; `tryEval` catches throws only.
  sealedMarker = {
    sealed = true;
  };
  preimageTagOf =
    hashIdentity: v:
    let
      carriesMint = builtins.tryEval (builtins.isAttrs v && v ? __mint);
    in
    if !carriesMint.success then
      { undefined = true; }
    else if carriesMint.value then
      let
        i = identityOf v;
      in
      # a mark beside sealed components enters by its mark (propagation hands the subjects up)
      if hasMark v then
        { inherit (v.__mint) minted; }
      else if isExact i then
        { inherit (i) minted; }
      else
        sealedMarker
    else
      let
        attempt = builtins.tryEval (hashIdentity "component" [ "value" ] (_: v));
      in
      if attempt.success then { inert = attempt.value; } else sealedMarker;

  # A composite's components, as a list of `{ path; value; sealed ? false; }` (`path` a list of
  # segments), to its preimage and its sealed subjects. Both maps are keyed by the path's
  # segments RFC 6901-escaped and joined with "." — `rec.nix` `flattenAttrs`'s key encoding, which
  # is injective where a bare join is not. `sealed` maps each SEALED component to
  # the value a `==` decision compares — the reified value itself, or a registered construction's
  # declared subject (`comparisonSubject`). A composite mints over `tags`; a door comparing two composites hands
  # `sealed` to `sealedCollisionEq`. ONE call yields both, so the two cannot read different planes.
  #
  # Two more entries, each what keeps a mark from deciding more than its preimage holds:
  #   · a DECLARED subject (a registered construction, `mkIntensional`) enters as `{ compared =
  #     <subject>; }`, the entry `sealedCollisionEq`'s evidence clause reads;
  #   · PROPAGATION: a minted component that itself carries a non-empty `__sealed` (a type or a kind
  #     over a sealed component) enters by its mark AND hands its `__sealed` over under its path.
  #     Its mark is blind to what it sealed, so without this a parent over `listOf (typedef R1)` and
  #     one over `listOf (typedef R9)` would share a mark and an empty sealed map and decide `true`.
  #     A propagated map holding a departed entry is handed up as one departed entry over the map
  #     with each departed entry stripped to its subject (`hoistDeparted`), so `sealedCollisionEq`,
  #     which reads the top level, refuses it at any depth: each level's map is one call's output.
  hoistDeparted =
    m:
    let
      departed = builtins.filter (k: isDepartedEntry m.${k}) (builtins.attrNames m);
    in
    if departed == [ ] then
      m
    else
      {
        __departed = m.${builtins.head departed}.__departed;
        __subject =
          m
          // builtins.mapAttrs (_: v: v.__subject) (
            builtins.intersectAttrs (builtins.listToAttrs (
              map (k: {
                name = k;
                value = null;
              }) departed
            )) m
          );
      };
  componentsPreimage =
    hashIdentity: components0:
    let
      propagates =
        c: c.tag ? minted && builtins.isAttrs (c.value.__sealed or null) && c.value.__sealed != { };
      # An honest caller's shape mistake is refused by name, never an uncatchable missing attribute.
      components =
        if
          builtins.isList components0
          && builtins.all (
            c:
            builtins.isAttrs c
            && c ? value
            && builtins.isList (c.path or null)
            && builtins.all builtins.isString c.path
            && builtins.isBool (c.sealed or false)
          ) components0
        then
          components0
        else
          throw "componentsPreimage: expected a list of { path = [ <string segment> ]; value; sealed ? <bool>; }";
      tagged = map (
        c:
        c
        // {
          name = builtins.concatStringsSep "." (
            map (builtins.replaceStrings [ "~" "." ] [ "~0" "~1" ]) c.path
          );
          tag = if c.sealed or false then sealedMarker else preimageTagOf hashIdentity c.value;
        }
      ) components;
      tags = builtins.listToAttrs (
        map (c: {
          inherit (c) name;
          value = c.tag;
        }) tagged
      );
    in
    # Two components at one path would keep the first and DROP the other silently (`listToAttrs`),
    # so the composite would mint over a partial preimage: refused by name instead.
    if builtins.length (builtins.attrNames tags) != builtins.length tagged then
      throw "componentsPreimage: two components share a path; each component needs its own path"
    else
      {
        inherit tags;
        sealed = builtins.listToAttrs (
          # A value with no declared subject is handed over as the component record itself (`listToAttrs` reads its
          # `name` and `value`), because `//` carries attribute slots while any `value = …` binding
          # is a fresh thunk. The copy keeps the value SLOT so that Nix `==` can apply its documented
          # value-identity optimisation (Nix manual, "Equality" under Language Values, on `==` for
          # functions); a function has no identity of its own (ADR-0034). Fail-closed: an evaluator
          # that drops the optimisation compares two shared-lambda components unequal, and the
          # result is a refusal by name, never a false admit.
          map (
            c:
            if declaresSubject c.value then
              c // { value = subjectEntry c.value { compared = c.value.__mint.unmintable.subject; }; }
            else
              c
          ) (builtins.filter (c: c.tag == sealedMarker) tagged)
          ++ map (c: c // { value = hoistDeparted c.value.__sealed; }) (builtins.filter propagates tagged)
        );
      };

  # THE COLLISION REFUSAL (c+). `a` and `b` are `{ name; mark; sealed; }`, `mark` minted over a
  # `componentsPreimage`'s `tags` and `sealed` its `sealed`. Distinct marks decide `false`; equal
  # marks with `==` sealed subjects decide `true`; equal marks with unequal subjects are two
  # declarations the mark cannot tell apart, and ADR-0034 replaces that collapse with a refusal
  # BY NAME. The decision is ONE `==` over the whole subject (the component-list clause); the
  # component names are read only to word the refusal. Two separately built lambdas are unequal,
  # so a sealed twin built twice is refused: the sound direction, and `conservativeEq`'s residue.
  # A subject with a throwing member can make `==` throw before it reaches a differing one, so
  # each `==` runs under `tryEval` and a throw counts as unequal: the refusal is by name either way.
  #
  # ★ THE EVIDENCE CLAUSE. An unequal pair whose every differing leaf is a DECLARED subject
  # (`{ compared = <subject>; }`, `componentsPreimage`) with an INERT subject on both sides decides
  # `false`; every other unequal pair is refused as above. The ground is ADR-0034's regimes: a
  # COMPARED component is a decision predicate, decisions only, so the inequality of two inert
  # subjects is evidence of two constructions; a sealed lambda's inequality under `==` is an
  # allocation fact and evidence of nothing, and its collapse "is replaced by a refusal". A declared
  # subject is inert only by its author's say-so (its `args` may hold a lambda), so inertness is
  # TESTED, by a bounded walk under `tryEval`, and a subject that fails it is refused. Equality is
  # still the one `==` over the whole subject; the per-leaf reading only classifies an inequality,
  # and runs only on the unequal path of an equal-mark pair.
  inertDepth = 64;
  inertWalk =
    d: v:
    if d == 0 || builtins.isFunction v || builtins.isPath v then
      false
    else if builtins.isList v then
      builtins.all (inertWalk (d - 1)) v
    else if builtins.isAttrs v then
      (v.type or null) != "derivation" && builtins.all (inertWalk (d - 1)) (builtins.attrValues v)
    else
      true;
  isInert =
    v:
    let
      r = builtins.tryEval (inertWalk inertDepth v);
    in
    r.success && r.value;
  isCompared = v: builtins.isAttrs v && builtins.attrNames v == [ "compared" ];
  isEvidence =
    eq: x: y:
    if isCompared x && isCompared y then
      isInert x.compared && isInert y.compared
    else if builtins.isAttrs x && builtins.isAttrs y && !(isCompared x) && !(isCompared y) then
      let
        slice = k: builtins.intersectAttrs { ${k} = null; };
      in
      builtins.all (
        k: eq (slice k x) (slice k y) || (x ? ${k} && y ? ${k} && isEvidence eq x.${k} y.${k})
      ) (builtins.attrNames (x // y))
    else
      false;
  sealedCollisionEq =
    site: a: b:
    let
      eq =
        x: y:
        let
          r = builtins.tryEval (x == y);
        in
        r.success && r.value;
    in
    if
      !(builtins.all
        (x: builtins.isAttrs x && x ? name && x ? mark && builtins.isAttrs (x.sealed or null))
        [
          a
          b
        ]
      )
    then
      throw "${site}: sealedCollisionEq expects two { name; mark; sealed = { <component> = <subject>; }; }"
    else if a.mark != b.mark then
      false
    else
      let
        # a departed component is decided over the subject it carries; it can only be refused, never
        # admitted, at an equal one (`subjectEntry`)
        departed = builtins.filter (
          k: isDepartedEntry (a.sealed.${k} or null) || isDepartedEntry (b.sealed.${k} or null)
        ) (builtins.attrNames (a.sealed // b.sealed));
        # only the departed keys are rebuilt: `//` keeps every other component's slot, which `==`'s
        # value-identity shortcut reads (a rebuilt binding is a fresh thunk)
        strip =
          m:
          m
          // builtins.mapAttrs (_: v: if isDepartedEntry v then v.__subject else v) (
            builtins.intersectAttrs (builtins.listToAttrs (
              map (k: {
                name = k;
                value = null;
              }) departed
            )) m
          );
        sa = strip a.sealed;
        sb = strip b.sealed;
        reasonAt =
          k:
          if isDepartedEntry (a.sealed.${k} or null) then
            a.sealed.${k}.__departed
          else
            b.sealed.${k}.__departed;
      in
      if eq sa sb then
        if departed == [ ] then
          true
        else
          throw "${site}: '${a.name}' holds component(s) ${
            builtins.concatStringsSep ", " (map (k: "'${k}'") departed)
          } that are not the value their producer completed: ${reasonAt (builtins.head departed)}; build the change through its producer"
      else if isEvidence eq sa sb then
        false
      else
        sealedRefusal site a.name sa sb;
  sealedRefusal =
    site: name: sa: sb:
    let
      eq =
        x: y:
        let
          r = builtins.tryEval (x == y);
        in
        r.success && r.value;
      # Each component is compared inside a one-key slice (`intersectAttrs` carries the slot): a
      # bare `a.sealed.${k}` argument is a fresh thunk, so upstream Nix would name a component
      # holding one shared lambda as differing, and Lix would not. A key `b` lacks slices to `{ }`.
      slice = k: builtins.intersectAttrs { ${k} = null; };
      differing = builtins.filter (k: !(eq (slice k sa) (slice k sb))) (builtins.attrNames sa);
    in
    throw "${site}: two declarations of '${name}' mint one identity and are unequal only at sealed component(s) ${
      builtins.concatStringsSep ", " (map (k: "'${k}'") differing)
    }: a sealed component is compared by its seal, the whole value under Nix `==`, where two separately built functions are never equal, so two separate constructions are refused even where the values they compute are equal; a sealed component has no identity, because identity is minted from inert structure alone: migrate it to a first-order term, a registered constructor over inert arguments, so that it mints";

  # ── the encoder ──
  #
  # ★ THIS CONSTRUCTION IS LORENZEN'S LAZY CONSTRUCTOR (§1). A lazy constructor carries INERT
  # FIRST-ORDER OPERANDS and no behaviour at all: "whenever the run-time encounters an SAppend
  # constructor, the associated right-hand side of the data declaration is executed". The behaviour is
  # looked up BY CONSTRUCTOR at forcing, out of the declaration, so the operands can be read before
  # anything is forced — Lorenzen's `debug-show` prints a lazy constructor without forcing further
  # evaluation. That is `{ ctor; args; }` inert with `registry.members.<ctor> args` applied only at
  # demand, through `__functor`, and it is why `closure` needs no reification of its own: the operands ARE the value.
  #
  # WHERE THIS FORM IS OPEN AND LORENZEN'S IS CLOSED — which is what puts `revision` in the coordinate
  # below. §8 names the closure as a limitation: lazy constructors "have to be declared up-front in the
  # data type definition", so one declaration site fixes the whole constructor-to-behaviour map and no
  # coordinate is needed to say which map was meant. Here the registry is a VALUE a caller supplies, so
  # the map is open and two registries may offer one `ctor` over two builders.
  #
  # ★ REYNOLDS §6 (pp. 376-377) IS THE CONSTRUCTOR-PLUS-INERT-ARGUMENT SHAPE AND NOTHING MORE — NOT
  # THIS REGISTRY. Three differences, each load-bearing here. His record's fields are READ OFF the
  # lambda's own global variables — §6's table gives one record equation per lambda expression, keyed
  # by the "Global Variables" column — where an author here CHOOSES what `args` holds. Elimination is a
  # single interpretive `apply` doing CLOSED case analysis over `FUNVAL = CLOSR ∪ SC ∪ EQ1 ∪ EQ2`,
  # where dispatch here is an attribute selection into an open map. And that union is enumerated from
  # every lambda expression in the program, making it a whole-program transformation with no registry
  # to pass at all. What transfers is only the shape: replace a function value by a tag plus inert
  # fields, and interpret the tag.
  #
  # ★ WHY THE REGISTRY COORDINATE IS IN THE PREIMAGE, and it is Palmer's §6.1 capture rule doing the
  # work. A builder is defined inside a registry module, so its free variables are its parameter
  # PLUS that module instance's own lexical scope — its dependency parameters and its let-bindings.
  # Palmer's GHC encoding excludes top-level bindings because LINKING supplies them; Nix has no
  # linking, so every cross-module reference is a lexical capture of an imported value and there is
  # no excluded class. Hence `fv(builder body) \ {param} ⊆ args ∪ scope(registry instance)`, and the
  # coordinate must cover both terms: `args` structurally, the registry instance through this
  # coordinate. Without the second term two pins of the substrate give the same `ctor` and the same
  # `args` ONE identity for TWO behaviours.
  #
  # `members` is DERIVED — the member name set is inert and discriminates registries with differing
  # surfaces. `revision` is DECLARED, because two registries with the same member names and
  # different builder bodies are indistinguishable to every builtin: none exposes a lambda's body or
  # its captured environment. The obligation that declaration carries is that the revision changes
  # whenever any builder's behaviour changes, INCLUDING through an injected dependency; the residue
  # is that an author can get it wrong, which is why Palmer's closure-consistency hypotheses
  # discharge CONDITIONALLY here rather than outright. The condition disappears entirely if builders
  # become first-order TERMS, at which point the coordinate is derived from the terms and nothing is
  # declared.
  #
  # Until that migration, the coordinate below discharges only CONDITIONALLY, on the declared
  # `revision` holding its obligation: that makes the digest it feeds fit as a COMPARED decision
  # predicate, never a MINTED key, so it must not be handed to gen-dispatch's `taggedHandle` while
  # the condition stands. The encoder below computes no digest over it at all: the coordinate is the
  # head of its declared comparison subject.
  registryCoordOf = registry: {
    members = builtins.attrNames registry.members;
    inherit (registry) revision;
  };

  # mkIntensional : hashIdentity -> registry -> ctor -> args -> Intensional
  #
  # `registry` is `{ revision; members; }`, where `members` maps a constructor name to a builder
  # taking the inert argument value. `revision` is REQUIRED AND TOTAL — a registry without one is
  # refused BY NAME at construction and never defaulted, because a default would silently mean "no
  # constraint" at exactly the place the constraint is load-bearing.
  mkIntensional =
    hashIdentity: registry: ctor: args:
    if !(registry ? revision) then
      throw "intensional: registry declares no revision"
    else if !(registry ? members) then
      throw "intensional: registry declares no members"
    else if !(registry.members ? ${ctor}) then
      throw "intensional: unknown constructor '${ctor}'"
    else
      let
        fn = registry.members.${ctor} args;
        self = {
          inherit ctor args;

          # ★ `name` DOES EXACTLY ONE JOB — IT ANSWERS A SHAPE GUARD — AND IT IS NEVER A KEY. It is
          # Palmer's `itsIdentify` slot, and what changes here is the program point's SOURCE:
          # caller-supplied becomes registry-derived. Four shipped guards conjoin on `v ? name`, so
          # dropping the field would make an encoder-built value inadmissible everywhere; keeping it
          # without saying which job it does is what let consumers key on it.
          #
          # ★ `name = ctor` IS CONSTANT PER CONSTRUCTOR BY DESIGN — that constancy is what a program
          # point IS. A consumer that keys on `name` alone is therefore shipping Palmer's first
          # conjunct without the second, which is the defect this construction exists to remove: the
          # KEY job belongs to the mint, and every key site reads it through `identityOf`.
          #
          # `name` is NEVER HASHED. The program point is already in the coordinate as `ctor`, so
          # hashing it would double-count. Def 5.7(3) is not re-opened by deriving it: the hole was a
          # CALLER-SUPPLIED name letting two bodies share one point, and a derived name is fixed by the
          # registry — same name plus same registry implies same builder implies same body. Across
          # registries names may collide while identities cannot.
          name = ctor;

          # The reified closure keeps its field name, so every shipped shape guard admits an
          # encoder-built value. It IS `args`: there is no second thing to under-supply.
          closure = args;

          # ★ COMPARED, NEVER MINTED (den-hoag-hhki8; ADR-0034's compared regime). The coordinate above
          # discharges only CONDITIONALLY, on the declared `revision`, so a digest over it is fit as a
          # decision predicate and never as a key. The value therefore carries no mint: it DECLARES its
          # comparison subject, the registry coordinate, the constructor and the inert argument value
          # (ADR-0034's component-list clause: "The constructor's declared component list names what that
          # comparison's SUBJECT must be"). Every key site reads the tag through `identityOf` and finds no
          # exact identity: `isExact` is `false`, a composite tags it with `sealedMarker`, and
          # gen-dispatch's `taggedHandle` answers no handle. Every decision reads `subject` through
          # `comparisonSubject`, so two constructions of one term decide `true` and a different argument,
          # member set or revision decides `false`. No digest is computed.
          __mint = {
            unmintable = {
              inherit ctor;
              reason = "a registered construction is compared by its declared subject (registry coordinate, constructor, inert arguments), never minted: its coordinate discharges only on the declared `revision`";
              subject = {
                registry = registryCoordOf registry;
                inherit ctor args;
              };
            };
          };

          # The forcing step, and the ONLY place behaviour enters the value: Lorenzen's "associated
          # right-hand side of the data declaration", looked up by constructor when demand arrives.
          # No other field forces it — not `name`, not `closure`, not the mint's preimage — so the
          # operands stay readable on a value nobody has applied. The builder application is a `let`
          # binding, never a slot: Nix and Determinate force a slot before `==`'s pointer shortcut, so a
          # stored application would be applied by the stamp's comparison.
          __functor = _: fn;
          # the completion witness: a `//` copy still returns this value, so `standingOf` tells a
          # departed copy from the value completed here
          __intensionalSelf = _: self;
          __witness = {
            completion = "__intensionalSelf";
          };
        };
      in
      self;

  # CONSERVATIVE EQUALITY — Palmer's own term (§2.3, §5.3, §8). "Intensional" qualifies the
  # FUNCTION and never the equality, and the misnomer is what read as a licence to compare intension
  # alone: Palmer's Fig. 5 is a CONJUNCTION over identity AND closure, so a name-only relation ships
  # one half of it and COARSENS — it calls behaviourally distinct functions equal, which is the one
  # direction §2.3's guarantee forbids.
  #
  # ★ THE PRODUCER'S WITNESSES ARE READ FIRST. Each operand's declared witnesses (`__witness`, above)
  # give it a standing: `refused` on either operand (a `//` copy departing from what its producer
  # completed, or a malformed or uncheckable declaration) throws a refusal by name; `compared` on
  # either (a wrapper rewrote a field the mark was minted over) decides over `comparisonSubject`,
  # because that mark is a bucket label; `holds` leaves the arms below to decide.
  #
  # TWO ARMS, and over non-derivation operands neither merges more than Fig. 5 — Nix `==` compares
  # two `type = "derivation"` attrsets by `outPath` alone, so a derivation-shaped pair differing
  # only in `closure` compares EQUAL; ADR-0034 excludes every derivation. Minted values compare by digest, which is exact
  # and fuses both of Fig. 5's conjuncts into one comparison. EVERY OTHER PAIR — sealed, unmigrated,
  # or mixed — falls through to THE REIFIED VALUE (`comparisonSubject`), and never a list of
  # components: ADR-0034's decision clause, "where it decides rather than mints, it
  # compares the reified value itself under Nix `==`". Its precision there is an allocation
  # artefact on lambda-carrying values, so two separately-constructed equal-shaped values compare
  # unequal and that arm merges strictly LESS than Fig. 5; on inert values it both identifies and
  # separates.
  #
  # ★ THERE IS NO NAME ARM. An unmigrated value's `name` is its program point, and deciding on it
  # alone merges strictly MORE — two values at one point with differing closures would compare EQUAL
  # where Fig. 5 separates them, the one direction §2.3 forbids. The name remains the unmigrated
  # regime's bucket LABEL at a key site, where a structural comparison follows it (`isExact`'s
  # obligation); it never decides here.
  #
  # ★ THE FALL-THROUGH IS TOTAL OVER INERT OPERANDS, AND PARTIAL OVER TWO POPULATIONS — a caller
  # payload that refuses under any key (a catchable refusal), and a self-referential payload (an
  # UNCATCHABLE evaluator abort) whose closures are all shared, so `comparisonSubject`'s prefix does
  # not decide before the record's `==` reaches the back-edge; where the closures differ, the prefix
  # decides `false` first. That is a
  # property of structural equality over caller data, shared with any key site's bucket scan and with
  # gen-select's `selectorEq`, which rules the same boundary. Closing it is a BOUNDED walk, which
  # ADR-0034 gives the mint and not this clause; it is an open design question, not a local fix.
  #
  # A component-wise conjunct is not the remedy: ADR-0034's component-list clause rules that a
  # constructor's declared components name what the comparison's SUBJECT must be, and never a set of
  # components to be compared one by one. The foreclosure rests on that clause ALONE — not on any
  # claim that a component-wise form cannot work. Nix `==` short-circuits on pointer identity, so an
  # attribute selection compares TRUE against itself even when the selected value holds a lambda,
  # and the component-wise form would be FINER rather than empty; only separately allocated lambdas
  # compare false.
  conservativeEq =
    a: b:
    let
      ia = identityOf a;
      ib = identityOf b;
      sa = standingOf a;
      sb = standingOf b;
      bad = if sa ? refused then a else b;
      why = if sa ? refused then sa.refused else sb.refused;
    in
    # two declared subjects that differ are two values that differ (the subject is inert): `false`,
    # before either stamp is read; a stamp is owed only where the answer could be a wrong `true`
    if
      declaresSubject a && declaresSubject b && a.__mint.unmintable.subject != b.__mint.unmintable.subject
    then
      false
    else if sa ? refused || sb ? refused then
      throw "gen-algebra: conservativeEq: `${nameOf bad}' is not the value its producer completed: ${why}; build the change through its producer"
    else if sa ? compared || sb ? compared then
      subjectAt sa a == subjectAt sb b
    else if hasMark a && hasMark b && (sealsSomething a || sealsSomething b) then
      sealedCollisionEq "conservativeEq"
        {
          name = nameOf a;
          mark = a.__mint.minted;
          sealed = a.__sealed or { };
        }
        {
          name = nameOf b;
          mark = b.__mint.minted;
          sealed = b.__sealed or { };
        }
    else if ia ? minted && ib ? minted then
      ia.minted == ib.minted
    else
      subjectAt sa a == subjectAt sb b;
in
{
  inherit
    hasMark
    markOf
    mkIntensional
    conservativeEq
    identityOf
    regimeTagOf
    isExact
    comparisonSubject
    hasDeclaredSubject
    declaresSubject
    subjectEntry
    sealedMarker
    preimageTagOf
    componentsPreimage
    sealedCollisionEq
    ;
}
