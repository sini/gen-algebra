# The term algebra's gating cells (den-hoag-lwbb1 unit 1, §3a). Shared by
# ci/tests/term.nix (nix-unit) and the three-evaluator probe in den-ag-design's report. Every
# `expr` is JSON-representable so the probe can print what it got.
{ genAlgebra, genIdentity }:
let
  inherit (genIdentity) hashIdentity;
  T = genAlgebra.term hashIdentity;
  inherit (T)
    term
    checkClause
    checkTerm
    resolveTerm
    ;
  inherit (genAlgebra) identityOf;
  code = r: r.left.code or "admitted";

  D = [
    "thimble"
    "bobbin"
  ];
  ctx = {
    thimble = "x";
    bobbin = 1;
  };

  # gen-demo `tuck`, first-order (design Section 3): `has thimble` => description.
  tuckBody = term.attrs {
    description = term.concat [
      (term.lit "tuck-")
      (term.readCtx "thimble" [ ])
    ];
  };
  tuck = {
    condition = term.has "thimble";
    body = tuckBody;
  };
  fire =
    env: cl:
    let
      c = resolveTerm env cl.condition;
    in
    if c ? left then
      c
    else if c.right then
      resolveTerm env cl.body
    else
      { right = null; };

  slots = {
    isKey = k: k == "nixos";
    admits = builtins.isFunction;
  };
  modA = { pkgs, ... }: { };
  modB = { config, ... }: { };
  idOf = t: identityOf t;
  mintOf = t: (identityOf t).minted or "<no-identity>";
  # Operand pairs for the order-independence cells: present-true / present-false / declared-absent
  # `has` and `eq` / negated / always / never.
  oiDeclared = [
    "host"
    "user"
  ];
  oiCtx = {
    host.name = "h";
  };
  oiOps = {
    Th = term.has "host";
    Te = term.eq [ "host" "name" ] "h";
    Fe = term.eq [ "host" "name" ] "z";
    Ah = term.has "user";
    Ae = term.eq [ "user" ] "x";
    NAh = term.not (term.has "user");
    AL = term.always;
    NV = term.not term.always;
  };
  oiNames = builtins.attrNames oiOps;
  oiPairs = builtins.concatMap (
    a: builtins.concatMap (b: if a < b then [ { inherit a b; } ] else [ ]) oiNames
  ) oiNames;
  cwEnv = {
    context = oiCtx;
    declared = oiDeclared;
  };
  owEnv = {
    context = oiCtx;
  };
  shown = r: if r ? left then "refused:" + r.left.code else builtins.toJSON r.right;
  oiRun =
    env: conn: a: b:
    shown (
      resolveTerm env (
        term.${conn} [
          oiOps.${a}
          oiOps.${b}
        ]
      )
    );
  orderDiffer =
    env: conn:
    map (p: "${p.a}/${p.b}") (
      builtins.filter (p: oiRun env conn p.a p.b != oiRun env conn p.b p.a) oiPairs
    );
  oiValue = n: (resolveTerm cwEnv oiOps.${n}).right;
  booleanMismatch =
    conn: f:
    map (p: "${p.a}/${p.b}") (
      builtins.filter (
        p:
        oiRun cwEnv conn p.a p.b != builtins.toJSON (
          f (n: oiValue n) [
            p.a
            p.b
          ]
        )
        ||
          oiRun cwEnv conn p.b p.a != builtins.toJSON (
            f (n: oiValue n) [
              p.a
              p.b
            ]
          )
      ) oiPairs
    );
  src = "entity:" + builtins.concatStringsSep "" (builtins.genList (_: "a") 64);
in
{
  # ── safety: a safe clause is admitted and evaluates ──
  safe-clause-admitted = {
    expr = code (checkClause { declared = D; } tuck);
    expected = "admitted";
  };
  safe-clause-fires = {
    expr = fire {
      context = ctx;
      declared = D;
    } tuck;
    expected = {
      right = {
        description = "tuck-x";
      };
    };
  };
  # ── safety: outside the safe fragment, refused by name ──
  unsafe-always-refused = {
    expr = code (
      checkClause { declared = D; } {
        condition = term.always;
        body = tuckBody;
      }
    );
    expected = "unsafe-read";
  };
  unsafe-names-the-read = {
    expr =
      map (r: r.head)
        (checkClause { declared = D; } {
          condition = term.always;
          body = tuckBody;
        }).left.witness.uncovered or [ ];
    expected = [ "thimble" ];
  };
  unsafe-disjunction-refused = {
    expr = code (
      checkClause { declared = D; } {
        condition = term.any [
          (term.has "thimble")
          (term.has "bobbin")
        ];
        body = tuckBody;
      }
    );
    expected = "unsafe-read";
  };
  unsafe-negation-refused = {
    expr = code (
      checkClause { declared = D; } {
        condition = term.not (term.has "thimble");
        body = tuckBody;
      }
    );
    expected = "unsafe-read";
  };
  eq-covers = {
    expr = code (
      checkClause { declared = D; } {
        condition = term.eq [ "thimble" ] "x";
        body = tuckBody;
      }
    );
    expected = "admitted";
  };
  conjunction-covers = {
    expr = code (
      checkClause { declared = D; } {
        condition = term.all [
          (term.has "bobbin")
          (term.has "thimble")
        ];
        body = tuckBody;
      }
    );
    expected = "admitted";
  };
  ref-reads-not-checked = {
    expr = code (
      checkClause { declared = D; } {
        condition = term.always;
        body = term.ref "door:r1";
      }
    );
    expected = "admitted";
  };
  condition-former-refused = {
    expr = code (
      checkClause { declared = D; } {
        condition = term.lit true;
        body = term.lit 1;
      }
    );
    expected = "condition-former";
  };
  # ── declared set: undeclared is ill-formed at declaration, with the declared set rendered ──
  undeclared-refused = {
    expr = code (
      checkClause { declared = D; } {
        condition = term.has "thimbel";
        body = term.lit 1;
      }
    );
    expected = "undeclared-name";
  };
  undeclared-did-you-mean = {
    expr =
      (checkClause { declared = D; } {
        condition = term.has "thimbel";
        body = term.lit 1;
      }).left.witness.message or "<admitted>";
    expected = "'thimbel' is not a declared coordinate; did you mean one of: thimble, bobbin";
  };
  open-world-no-declaration-check = {
    expr = code (
      checkClause { } {
        condition = term.has "thimbel";
        body = term.lit 1;
      }
    );
    expected = "admitted";
  };
  empty-set-is-closed-world = {
    expr = code (
      checkClause { declared = [ ]; } {
        condition = term.has "thimble";
        body = term.lit 1;
      }
    );
    expected = "undeclared-name";
  };
  # ── closed world: declared-but-absent is FALSE; `not` of it TRUE ──
  cw-absent-has-false = {
    expr = resolveTerm {
      context = { };
      declared = D;
    } (term.has "thimble");
    expected = {
      right = false;
    };
  };
  cw-absent-not-true = {
    expr = resolveTerm {
      context = { };
      declared = D;
    } (term.not (term.has "thimble"));
    expected = {
      right = true;
    };
  };
  cw-absent-eq-false = {
    expr = resolveTerm {
      context = { };
      declared = D;
    } (term.eq [ "thimble" ] "x");
    expected = {
      right = false;
    };
  };
  cw-tuck-does-not-fire = {
    expr = fire {
      context = {
        bobbin = 1;
      };
      declared = D;
    } tuck;
    expected = {
      right = null;
    };
  };
  atom-absent-path-false = {
    expr = resolveTerm {
      context = ctx;
      declared = D;
    } (term.eq [ "thimble" "missing" ] "x");
    expected = {
      right = false;
    };
  };
  # ── open world: R stands for `has` (refusal); `eq` keeps today's FALSE ──
  ow-absent-has-refuses = {
    expr = code (resolveTerm { context = { }; } (term.has "thimble"));
    expected = "absent-coordinate";
  };
  ow-absent-eq-false = {
    expr = resolveTerm { context = { }; } (term.eq [ "thimble" ] "x");
    expected = {
      right = false;
    };
  };
  # ── order independence under a declared set (ADR-0022): no checked atom refuses ──
  cw-any-order-a = {
    expr =
      resolveTerm
        {
          context = { };
          declared = D;
        }
        (
          term.any [
            (term.has "thimble")
            term.always
          ]
        );
    expected = {
      right = true;
    };
  };
  cw-any-order-b = {
    expr =
      resolveTerm
        {
          context = { };
          declared = D;
        }
        (
          term.any [
            term.always
            (term.has "thimble")
          ]
        );
    expected = {
      right = true;
    };
  };
  # ── order independence under a declared set, over every operand pair (ADR-0022) ──
  # `a·b` and `b·a` must agree for `any` and `all`, and equal the Boolean connective of the
  # operands' own values. The open world is the control: its accepted order dependence stays.
  cw-connective-order-independent = {
    expr = {
      any = orderDiffer cwEnv "any";
      all = orderDiffer cwEnv "all";
    };
    expected = {
      any = [ ];
      all = [ ];
    };
  };
  cw-connective-is-boolean = {
    expr = {
      any = booleanMismatch "any" builtins.any;
      all = booleanMismatch "all" builtins.all;
    };
    expected = {
      any = [ ];
      all = [ ];
    };
  };
  ow-connective-order-dependent = {
    expr = {
      any = orderDiffer owEnv "any";
      all = orderDiffer owEnv "all";
    };
    expected = {
      any = [
        "AL/Ah"
        "AL/NAh"
        "Ah/Te"
        "Ah/Th"
        "NAh/Te"
        "NAh/Th"
      ];
      all = [
        "Ae/Ah"
        "Ae/NAh"
        "Ah/Fe"
        "Ah/NV"
        "Fe/NAh"
        "NAh/NV"
      ];
    };
  };
  # ── the value-error clause: body reads only ──
  default-absent-path = {
    expr = resolveTerm {
      context = {
        host = { };
      };
    } (term.default "host" [ "name" ] (term.lit "x"));
    expected = {
      right = "x";
    };
  };
  default-present-path = {
    expr = resolveTerm {
      context = {
        host.name = "n";
      };
    } (term.default "host" [ "name" ] (term.lit "x"));
    expected = {
      right = "n";
    };
  };
  default-nonattrs-like-or = {
    expr = resolveTerm {
      context = {
        host = 1;
      };
    } (term.default "host" [ "name" ] (term.lit "x"));
    expected = {
      right = "x";
    };
  };
  read-absent-path-refuses = {
    expr = code (
      resolveTerm {
        context = {
          host = { };
        };
      } (term.readCtx "host" [ "name" ])
    );
    expected = "projection-path-missing";
  };
  # ── functions: refused everywhere except a declared module slot ──
  lit-lambda-refused = {
    expr = code (term.lit { nixos = modA; });
    expected = "lit-payload-function";
  };
  attrs-fn-refused-no-slots = {
    expr = code (checkTerm { } (term.attrs { nixos = modA; }));
    expected = "term-function";
  };
  attrs-fn-admitted-in-slot = {
    expr = code (checkTerm { inherit slots; } (term.attrs { nixos = modA; }));
    expected = "admitted";
  };
  attrs-fn-refused-off-slot = {
    expr = code (checkTerm { inherit slots; } (term.attrs { other = modA; }));
    expected = "term-function";
  };
  slot-admission-refused = {
    expr = code (
      checkTerm {
        slots = slots // {
          admits = _: false;
        };
      } (term.attrs { nixos = modA; })
    );
    expected = "module-slot-refused";
  };
  slot-payload-resolves-unapplied = {
    expr = builtins.isFunction (resolveTerm { } (term.attrs { nixos = modA; })).right.nixos;
    expected = true;
  };
  # ── identity: one mint, structural, round-trips ──
  id-is-the-mint = {
    expr = builtins.substring 0 5 (mintOf tuckBody);
    expected = "term:";
  };
  id-equal-constructions = {
    expr =
      mintOf tuckBody != "<no-identity>"
      &&
        mintOf tuckBody == (mintOf (
          term.attrs {
            description = term.concat [
              (term.lit "tuck-")
              (term.readCtx "thimble" [ ])
            ];
          }
        ));
    expected = true;
  };
  id-distinct-leaf = {
    expr =
      mintOf tuckBody == (mintOf (
        term.attrs {
          description = term.concat [
            (term.lit "tack-")
            (term.readCtx "thimble" [ ])
          ];
        }
      ));
    expected = false;
  };
  id-preimage-pinned = {
    expr = mintOf (term.lit 1);
    # `revision` is internal (not exported), so the cell pins the preimage with the literal value.
    expected = hashIdentity "term" [ "revision" "former" "fields" ] (
      l:
      {
        revision = "1";
        former = "Lit";
        fields = {
          value = 1;
        };
      }
      .${l}
    );
  };
  id-slot-payload-outside = {
    expr =
      let
        a = mintOf (term.attrs { nixos = modA; });
      in
      a != "<no-identity>" && a == mintOf (term.attrs { nixos = modB; });
    expected = true;
  };
  id-slot-position-inside = {
    expr =
      let
        a = mintOf (term.attrs { nixos = modA; });
      in
      a != "<no-identity>" && a == mintOf (term.attrs { home = modA; });
    expected = false;
  };
  id-path-lit-refused = {
    expr = (idOf (term.lit ./term-cells.nix)) ? unmintable;
    expected = true;
  };
  id-ref-mints = {
    expr = (idOf (term.ref "door:r1")) ? minted;
    expected = true;
  };
  ref-declaration-refused = {
    expr = code (term.ref { name = "x"; });
    expected = "ref-not-identifier";
  };
  ref-resolves-through-env = {
    expr = resolveTerm { ref = id: { right = "door-output:${id}"; }; } (term.ref "r1");
    expected = {
      right = "door-output:r1";
    };
  };
  ref-without-env-refuses = {
    expr = code (resolveTerm { } (term.ref "r1"));
    expected = "ref-unresolved";
  };
  # ── unit 1 (gate v0 C1-C3, P1, P5, P6, P9; null mint) ──
  has-undeclared-present = {
    expr = code (
      resolveTerm {
        context = {
          x = 1;
        };
        declared = D;
      } (term.has "x")
    );
    expected = "undeclared-name";
  };
  clause-missing-body-refused = {
    expr = code (checkClause { } { condition = term.always; });
    expected = "declaration-missing-field";
  };
  clause-not-a-record-refused = {
    expr = code (checkClause { } 1);
    expected = "declaration-missing-field";
  };
  apply-prim-fn-refused = {
    expr = code (term.apply (x: x) [ ]);
    expected = "former-operand-type";
  };
  apply-prim-int-refused = {
    expr = code (checkTerm { } (term.apply 5 [ ]));
    expected = "former-operand-type";
  };
  apply-prim-unknown-refused = {
    expr = code (checkTerm { } (term.apply "nope" [ ]));
    expected = "term-vocabulary";
  };
  readfrom-fn-target-refused = {
    expr = code (term.readFrom (x: x) [ ]);
    expected = "former-operand-type";
  };
  readfrom-fn-path-refused = {
    expr = code (term.readFrom "t" [ (x: x) ]);
    expected = "former-operand-type";
  };
  readfrom-admitted = {
    expr = code (checkTerm { } (term.readFrom "t" [ "a" ]));
    expected = "admitted";
  };
  eq-attrs-equal-fires = {
    expr = resolveTerm {
      context = {
        host = {
          name = "x";
        };
      };
    } (term.eq [ "host" ] { name = "x"; });
    expected = {
      right = true;
    };
  };
  eq-list-equal-fires = {
    expr = resolveTerm {
      context = {
        tags = [
          "a"
          "b"
        ];
      };
    } (term.eq [ "tags" ] [ "a" "b" ]);
    expected = {
      right = true;
    };
  };
  eq-path-same-fires = {
    expr = resolveTerm {
      context = {
        p = ./term-cells.nix;
      };
    } (term.eq [ "p" ] ./term-cells.nix);
    expected = {
      right = true;
    };
  };
  eq-path-vs-string-false = {
    expr = resolveTerm {
      context = {
        p = toString ./term-cells.nix;
      };
    } (term.eq [ "p" ] ./term-cells.nix);
    expected = {
      right = false;
    };
  };
  eq-path-unmintable = {
    expr = (idOf (term.eq [ "p" ] ./term-cells.nix)) ? unmintable;
    expected = true;
  };
  readctxheads-unique = {
    expr = T.readCtxHeads (term.default "h" [ ] (term.readCtx "h" [ ]));
    expected = [ "h" ];
  };
  id-ill-formed-child-unmintable = {
    expr = (idOf (term.attrs { a = 1; })) ? unmintable && (idOf (term.attrs { a = 2; })) ? unmintable;
    expected = true;
  };
  id-null-mint-refused = {
    expr = ((genAlgebra.term null).term.lit 1).__mint ? unmintable;
    expected = true;
  };
  # ── the registration identifier's field domain (gate contact 2 UC2): toJSON coerces a record with
  #    `outPath`/`__toString` to that string and copies a path into the store; both are refused ──
  ref-id-declared-round-trips = {
    expr =
      let
        r = {
          declared = {
            site = "m.nix#aspects/host/0";
            reads = [ "host" ];
          };
        };
      in
      builtins.fromJSON (T.refId r).right == r;
    expected = true;
  };
  ref-id-nested-round-trips = {
    expr =
      let
        r = {
          nested = {
            outer = "r";
            sources = {
              host = src;
            };
            position = [
              "includes"
              0
            ];
            reads = null;
          };
        };
      in
      builtins.fromJSON (T.refId r).right == r;
    expected = true;
  };
  ref-id-outpath-records-refused = {
    expr =
      map
        (
          v:
          code (
            T.refId {
              declared = {
                site = {
                  outPath = "x";
                  inherit v;
                };
                reads = null;
              };
            }
          )
        )
        [
          1
          2
        ];
    expected = [
      "ref-id-domain"
      "ref-id-domain"
    ];
  };
  ref-id-tostring-records-refused = {
    expr =
      map
        (
          v:
          code (
            T.refId {
              declared = {
                site = {
                  __toString = _: "x";
                  inherit v;
                };
                reads = null;
              };
            }
          )
        )
        [
          1
          2
        ];
    expected = [
      "ref-id-domain"
      "ref-id-domain"
    ];
  };
  ref-id-path-site-refused = {
    expr =
      (T.refId {
        declared = {
          site = ./term-cells.nix;
          reads = null;
        };
      }).left.witness.got or "<admitted>";
    expected = "path";
  };
  # ── resolveFields (den-hoag-bgeum; ADR-0010 §4(a) clause 3): each field resolved at its own read ──
  # A refusing member is handed to `onLeft` with its path; its siblings resolve. resolveTerm over the
  # same body refuses whole (the control).
  resolve-fields-per-field = {
    expr = {
      fields =
        T.resolveFields { context.host = "h1"; }
          (p: l: {
            refused = p;
            inherit (l) code;
          })
          (
            term.attrs {
              fine = term.lit "fine";
              bad = term.readCtx "host" [ "deep" ];
              xs = term.list [
                (term.readCtx "host" [ ])
                (term.readCtx "user" [ ])
              ];
              pick = term.ifThenElse (term.has "host") (term.attrs { a = term.readCtx "host" [ ]; }) (
                term.lit null
              );
              raw = 1;
            }
          );
      whole = code (
        resolveTerm { context.host = "h1"; } (term.attrs { bad = term.readCtx "host" [ "deep" ]; })
      );
    };
    expected = {
      fields = {
        fine = "fine";
        bad = {
          refused = [ "bad" ];
          code = "projection-path-missing";
        };
        xs = [
          "h1"
          {
            refused = [
              "xs"
              1
            ];
            code = "read-absent";
          }
        ];
        pick.a = "h1";
        raw = 1;
      };
      whole = "projection-path-missing";
    };
  };
  # An `If` whose condition is not a bool refuses through resolveTerm's own check (decideIf, shared).
  resolve-fields-if-condition-checked = {
    expr = map (f: f (term.ifThenElse (term.readCtx "host" [ ]) (term.lit 1) (term.lit 2))) [
      (T.resolveFields { context.host = "h1"; } (_: l: l.witness))
      (b: (resolveTerm { context.host = "h1"; } b).left.witness)
    ];
    expected = [
      {
        former = "If";
        position = "cond";
        expected = "bool";
        got = "string";
      }
      {
        former = "If";
        position = "cond";
        expected = "bool";
        got = "string";
      }
    ];
  };
  # ADR-0010 §4(a) clause 4 is VACUOUS because no former binds a coordinate: every former hands the
  # same env to its children, so substitutions along a projection path never shadow. A former that
  # binds a coordinate RE-OPENS clause 4 (reverse-order normalisation, van Antwerpen 2018 (N-All)).
  known-formers-bind-no-coordinate = {
    expr = T.knownFormers;
    expected = [
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
  };
  codes-carried-from-bodyterm = {
    expr = map code [
      (resolveTerm { } (term.readFrom "t" [ ]))
      (resolveTerm { } (term.concat [ (term.lit ./term-cells.nix) ]))
      (resolveTerm { } (term.pathJoin (term.lit "s") [ ]))
    ];
    expected = [
      "readfrom-names-non-member"
      "path-operand-store-copying-former"
      "pathjoin-operand"
    ];
  };
}
