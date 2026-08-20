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
# flake dependency cycle. Taking it as a CONSTRUCTOR PARAMETER mints the value inside the eval doing
# the constructing — the consumer's own — so the identity is OWNED rather than borrowed and no
# second minting authority is introduced. gen-algebra keeps its zero-dependency property: nothing is
# imported here, the authority arrives as an argument.
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
  # This discipline lives HERE, with the constructor that emits the tag, and `search.nix` reads it
  # from here rather than keeping its own copy: one tagged sum with two readers is how the two stop
  # agreeing.
  #
  # ★ THAT CONSOLIDATION IS REPO-LOCAL, AND CLAIMING MORE WOULD OVERSTATE IT. Measured across
  # `gen-*/lib`: `identityOf` has FOUR independent definitions — this one, gen-select's, gen-types'
  # and gen-dispatch's — with `comparisonSubject` and `conservativeEq` at three apiece. gen-types is
  # the sharpest counterexample, being a leaf that cannot import this file without closing the very
  # dependency cycle the injected mint exists to avoid. So what holds is "one author WITHIN
  # gen-algebra", not across the ecosystem, and the copies are a live divergence risk rather than a
  # solved problem. Relocating the minting authority to a leaf is what would dissolve the constraint
  # keeping them apart.
  identityOf =
    v:
    if v ? __mint && v.__mint ? minted then
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
  isExact = i: i ? minted;

  # The comparison SUBJECT for the non-exact arms: the reified value MINUS `__id`, and minus nothing
  # else. `__id` is the ACCESSOR a consumer reads when it DEMANDS an identity, and where nothing is
  # minted that accessor IS the named refusal — so it is not distinguishing content, and forcing it
  # inside a comparison would detonate the very decision the refusal exists to permit. `removeAttrs`
  # preserves the evaluator's cell fast path and is a byte-for-byte no-op on a value carrying no
  # `__id`, so this excludes the accessor without emptying the relation.
  #
  # ★ WHY EXCLUDING `__id` IS SUFFICIENT AND NOT ARBITRARY. It is the only OTHER refusal-valued
  # accessor a compared value can carry, because `__mint.minted` is shielded by the tagged sum's own
  # shape: the minted and sealed arms live under DIFFERENT KEY NAMES, and Nix `==` decides on the
  # name set before forcing any value. Two sealed values carry inert payloads under one name, so
  # nothing forces there either. The one path that does force a mint is a minted-against-minted
  # comparison, and that arm never reaches here: it compares digests, which is a genuine DEMAND for
  # an identity, where a catchable named refusal is the correct outcome rather than a hazard.
  comparisonSubject = v: removeAttrs v [ "__id" ];

  # ── the encoder ──
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
      {
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

        fn = registry.members.${ctor} args;

        # LAZY: an intensional value nobody compares hashes nothing. The preimage is TOTAL over the
        # distinguishing content, which is what makes this a mint rather than a key — an identity
        # over a partial preimage merges behaviourally distinct values, and for a relation that
        # MINTS there is no safe direction to err in.
        __mint = {
          minted =
            hashIdentity "its"
              [
                "registry"
                "ctor"
                "args"
              ]
              (
                l:
                {
                  registry = registryCoordOf registry;
                  inherit ctor args;
                }
                .${l}
              );
        };

        __functor = self: self.fn;
      };

  # CONSERVATIVE EQUALITY — Palmer's own term (§2.3, §5.3, §8). "Intensional" qualifies the
  # FUNCTION and never the equality, and the misnomer is what read as a licence to compare intension
  # alone: Palmer's Fig. 5 is a CONJUNCTION over identity AND closure, so a name-only relation ships
  # one half of it and COARSENS — it calls behaviourally distinct functions equal, which is the one
  # direction §2.3's guarantee forbids.
  #
  # Minted values compare by digest, which is exact. Where nothing is minted this compares THE
  # REIFIED VALUE — minus `comparisonSubject`'s one exclusion — and never a list of components: a
  # bare `==` on a lambda is false always, and the evaluator's cell fast path appears only when the
  # lambdas are compared INSIDE a container the comparison reaches by the same reference. An
  # attribute selection is an indirection, so a component-wise form is false even against itself and
  # the relation would be EMPTY rather than finer. Its precision is an allocation artefact and is
  # declared as such: two separately-constructed equal-shaped values compare unequal, so the
  # relation merges strictly less than Fig. 5 and never more.
  conservativeEq =
    a: b:
    let
      ia = identityOf a;
      ib = identityOf b;
    in
    if ia ? minted && ib ? minted then
      ia.minted == ib.minted
    else if ia ? unmigrated && ib ? unmigrated then
      ia.unmigrated == ib.unmigrated
    else
      comparisonSubject a == comparisonSubject b;
in
{
  inherit
    mkIntensional
    conservativeEq
    identityOf
    regimeTagOf
    isExact
    comparisonSubject
    ;
}
