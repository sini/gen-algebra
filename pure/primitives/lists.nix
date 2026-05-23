# List operations — builtins only. No nixpkgs lib.
let
  inherit (builtins)
    length
    elemAt
    genList
    filter
    foldl'
    ;

  replicate = n: x: genList (_: x) n;

  last = xs: elemAt xs (length xs - 1);

  range = a: b: genList (i: a + i) (b - a + 1);

  imap0 = f: xs: genList (i: f i (elemAt xs i)) (length xs);

  reverse =
    xs:
    let
      len = length xs;
    in
    genList (i: elemAt xs (len - 1 - i)) len;

  indicesOfPred =
    pred: haystack:
    let
      indexed = imap0 (i: v: { inherit i v; }) haystack;
      filtered = filter (c: pred c.v) indexed;
    in
    map (x: x.i) filtered;

  indicesOf = needle: indicesOfPred (x: x == needle);

  indexOfDefault =
    default: needle: haystack:
    let
      idx = foldl' (i: el: if i < 0 then if el == needle then -i - 1 else i - 1 else i) (-1) haystack;
    in
    if idx < 0 then default else idx;

  indexOf = indexOfDefault null;

  lastIndexOf =
    needle: haystack:
    let
      indices = indicesOf needle haystack;
    in
    if indices == [ ] then null else last indices;

  elemAtDefault =
    default: index: list:
    if index >= 0 && index < length list then elemAt list index else default;

  removeElems = elems: filter (el: indexOf el elems == null);

  sublist =
    start: end: list:
    genList (i: elemAt list (start + i)) (end - start);

  split =
    needle: haystack:
    let
      idxs = indicesOf needle haystack;
      idxs0 = [ (-1) ] ++ idxs;
      idxs1 = idxs ++ [ (length haystack) ];
      pairs = imap0 (i: _: {
        fst = elemAt idxs0 i;
        snd = elemAt idxs1 i;
      }) idxs0;
    in
    map ({ fst, snd }: sublist (fst + 1) snd haystack) pairs;

  lsplit =
    needle: haystack:
    let
      idx = indexOf needle haystack;
      len = length haystack;
    in
    if idx == null then
      null
    else
      {
        l = sublist 0 idx haystack;
        r = sublist (idx + 1) len haystack;
      };

  rsplit =
    needle: haystack:
    let
      idx = lastIndexOf needle haystack;
      len = length haystack;
    in
    if idx == null then
      null
    else
      {
        l = sublist 0 idx haystack;
        r = sublist (idx + 1) len haystack;
      };

  lpad =
    fillElem: totalLen: list:
    replicate (
      let
        d = totalLen - length list;
      in
      if d > 0 then d else 0
    ) fillElem
    ++ list;

  rpad =
    fillElem: totalLen: list:
    list
    ++ replicate (
      let
        d = totalLen - length list;
      in
      if d > 0 then d else 0
    ) fillElem;
in
{
  inherit
    replicate
    last
    range
    imap0
    reverse
    indicesOf
    indicesOfPred
    indexOfDefault
    indexOf
    lastIndexOf
    elemAtDefault
    removeElems
    sublist
    split
    lsplit
    rsplit
    lpad
    rpad
    ;
}
