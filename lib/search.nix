# pure/search.nix — Palmer §3 Search monad. Zero dependencies.
let
  empty = {
    index = { };
    results = [ ];
    continuations = [ ];
  };

  lookup = key: state: state.index.${key} or [ ];

  has = key: state: state.index ? ${key};

  insert = key: value: state: {
    inherit (state) results continuations;
    index = state.index // {
      ${key} = (state.index.${key} or [ ]) ++ [ value ];
    };
  };

  emit = items: state: {
    inherit (state) index continuations;
    results = state.results ++ items;
  };

  foldl = f: builtins.foldl' f;

  on = key: fn: state: {
    inherit (state) index results;
    continuations = state.continuations ++ [
      {
        inherit key fn;
        processed = 0;
      }
    ];
  };

  # Private: list drop without lib dependency.
  drop =
    n: list:
    let
      len = builtins.length list;
    in
    if n >= len then [ ] else builtins.genList (i: builtins.elemAt list (i + n)) (len - n);

  # The identity-regime discipline and its three siblings come from `intensional.nix`, where the
  # constructor that EMITS the tag lives. They are not restated here: one tagged sum with two
  # readers is how the two stop agreeing, and the dedup loop below is a reader rather than an
  # author of the regime. See that file for why each arm exists and why the sealed arm's comparison
  # subject excludes `__id`.
  inherit (import ./intensional.nix)
    identityOf
    regimeTagOf
    isExact
    comparisonSubject
    ;

  # Private: dedup intensional continuations (Palmer §3).
  #
  # Palmer's Fig. 5 is a CONJUNCTION over identity AND closure, and the key this
  # replaces carried the first conjunct alone — `"${c.key}:${c.fn.name}"`. A program
  # point is constant across a constructor's instances, so two continuations watching
  # one index key and behaving differently shared a key and one was SILENTLY DROPPED.
  #
  # WHETHER A KEY IS A DEDUP KEY OR A BUCKET IS DECIDED HERE, NOT IN `keyOf`. A boolean
  # `seen` is not a bucket: there is nothing stored to compare against and nowhere for a
  # comparison to run, so re-keying alone would leave the drop exactly as it was. `seen`
  # therefore maps a key to the MEMBERS seen under it:
  #
  #   minted    — the key is exact, so presence is the whole test and the loop keeps its
  #               O(1) behaviour on it.
  #   otherwise — the key is a bucket label, and membership is decided by comparing THE
  #               REIFIED VALUE ITSELF — minus `comparisonSubject`'s one exclusion —
  #               against the bucket's members. It must be the whole value: an attribute
  #               selection is an indirection, so a component-wise form is false even
  #               against itself and the relation would be EMPTY rather than finer. Its
  #               precision is an allocation artefact, which for a relation that merges
  #               WORK is the safe direction — a finer relation costs dedup and never
  #               correctness.
  #
  # Every key carries its REGIME TAG between the index key and the payload, so the three
  # arms occupy disjoint key spaces and a name cannot forge a digest's key.
  #
  # The unmigrated arm takes the bucket too. That arm is where the shipped defect's own
  # witness lives — two same-named continuations with differing closures — so leaving it
  # on the presence test would ship the bug for the whole migration window.
  #
  # Non-intensional fns carry no key and pass through untouched.
  #
  # KNOWN RESIDUAL, inherited and not introduced here: the key is a concatenation, so
  # two continuations whose INDEX KEYS differ but whose `key:tag:payload` renderings
  # coincide still share a bucket. That costs a bucket scan rather than correctness, and
  # it is a property of `c.key` being interpolated raw, which predates the tag.
  dedupContinuations =
    conts:
    let
      # One `identityOf` read per continuation, feeding both the key and its exactness —
      # so the tagged sum keeps a single reader.
      classify =
        c:
        if !(c.fn ? name && c.fn ? closure) then
          null
        else
          let
            i = identityOf c.fn;
            payload = if i ? minted then i.minted else c.fn.name;
          in
          {
            key = "${c.key}:${regimeTagOf i}:${payload}";
            exact = isExact i;
          };
      go =
        seen: rest:
        if rest == [ ] then
          [ ]
        else
          let
            c = builtins.head rest;
            r = classify c;
            tail = builtins.tail rest;
            members = if r == null then [ ] else seen.${r.key} or [ ];
            subject = comparisonSubject c.fn;
            duplicate =
              r != null
              && (if r.exact then members != [ ] else builtins.any (m: comparisonSubject m == subject) members);
          in
          if duplicate then
            go seen tail
          else
            [ c ] ++ go (if r == null then seen else seen // { ${r.key} = members ++ [ c.fn ]; }) tail;
    in
    go { } conts;

  converge =
    state:
    let
      step =
        state:
        let
          deduped = dedupContinuations state.continuations;
          fired =
            builtins.foldl'
              (
                acc: cont:
                let
                  values = acc.state.index.${cont.key} or [ ];
                  unprocessed = drop cont.processed values;
                  result = builtins.foldl' (s: v: cont.fn v s) acc.state unprocessed;
                  newProcessed = builtins.length values;
                in
                {
                  state = result;
                  rebuilt = acc.rebuilt ++ [
                    {
                      inherit (cont) key fn;
                      processed = newProcessed;
                    }
                  ];
                  anyFired = acc.anyFired || (builtins.length unprocessed > 0);
                }
              )
              {
                state = state // {
                  continuations = [ ];
                };
                rebuilt = [ ];
                anyFired = false;
              }
              deduped;
          allContinuations = dedupContinuations (fired.rebuilt ++ fired.state.continuations);
        in
        {
          state = fired.state // {
            continuations = allContinuations;
          };
          anyFired = fired.anyFired;
        };
      iterate =
        n: state:
        if n <= 0 then
          throw "search: converge exceeded 1000 iterations — likely a non-terminating continuation"
        else
          let
            r = step state;
          in
          if r.anyFired then iterate (n - 1) r.state else r.state;
    in
    iterate 1000 state;

in
{
  inherit
    empty
    lookup
    has
    insert
    emit
    foldl
    on
    converge
    ;
}
