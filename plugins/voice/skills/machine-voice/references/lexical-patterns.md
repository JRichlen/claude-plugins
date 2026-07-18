# Lexical patterns

Four named compression patterns for machine-read elements. `SKILL.md` carries the
governing rule — drop discourse overhead, keep grammatical disambiguators. This
file is the detail: when each pattern fits and how each one fails.

## Block language

Noun-heavy, verbless, hierarchical. What YAML, JSON, schemas, and labeled
sections already are.

**Use for:** prompts, tool schemas, config, state snapshots, reference cards.

Instead of:

> You should first check the user's location, then look up the nearest branch,
> and finally return the hours of operation.

Write:

```yaml
task: branch_hours_lookup
steps:
  - resolve: user.location
  - lookup: nearest_branch
  - return: branch.hours
```

The structure *is* the context. No prose needed to glue it together.

**Fails when:** the relationship between items is conditional or causal. A
hierarchy expresses containment, not "only if". Push conditionals into explicit
keys (`when:`, `unless:`) rather than implying them by nesting.

## Headlinese

Newspaper-headline register. Drop articles, copulas, auxiliaries. Keep the
inflections that disambiguate.

**Use for:** status lines, tool-call summaries, log entries, progress updates.

Instead of:

> I have fetched 12 rows from the database and I noticed that there was a schema
> mismatch on column 3, so I am now going to retry with a type cast.

Write:

> `Fetched 12 rows. Schema mismatch col 3. Retrying with cast.`

~60% fewer tokens, zero ambiguity.

**Fails when:** dropping the copula creates a noun-phrase/clause ambiguity.
"User file corrupt" could be a state report or a command. Keep the copula when
the line could be read as an imperative.

## Asyndeton

Drop conjunctions between sequential items. Pairs naturally with headlinese.

**Use for:** action sequences, ordered steps, pipeline stages.

> `Parse. Validate. Route. Log.`

Not:

> First parse, then validate, and then route, and finally log.

**Fails when causation matters.** Asyndeton flattens causal ordering into mere
sequence — the reader sees four things that happened, not that each triggered
the next. Keep the conjunction where one step *causes* the next rather than
merely following it: `Validate → reject on failure. Route.` is clearer than
`Validate. Reject. Route.`

## Nominal style

Dotted namespacing for state. Noun phrases only.

**Use for:** state dumps, variable references, config keys.

```
user.auth.status: verified
cart.items.count: 3
retry.count: 0
retry.max: 3
```

**Fails when:** the namespace implies a hierarchy the underlying data does not
have. `retry.count` and `retry.max` genuinely share a parent; inventing
`user.cart.retry` to group unrelated keys misleads a reader who will try to
address the parent.

## Quick reference

| Pattern | Use for | Avoid in |
|---|---|---|
| Block language | Schemas, prompts, config | Conversational replies; conditional logic |
| Headlinese | Status, logs, tool summaries | Lines readable as imperatives |
| Asyndeton | Action sequences | Anywhere causation matters |
| Nominal style | State, config keys | Invented hierarchies |

Layer-2 thresholds, restated from `SKILL.md` so this card stands alone: headers
only for independently meaningful sections (under ~3 lines, use a bold lead-in);
lists only for parallel items; tables at ≥3 items × ≥2 attributes; one emoji per
line, at line start, never mid-prose.
