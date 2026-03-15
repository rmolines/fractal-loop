---
description: "Recursive fractal primitive. Evaluates the active predicate, finds the largest confident sub-predicate, and either executes (base case) or recurses (subdivision). State machine backed by filesystem."
argument-hint: "<tree-path>"
allowed-tools: Skill(fractal:recurse *), Skill(fractal:try *), Skill(fractal:planning *), Agent, Bash, Read, Write, Edit, Glob, AskUserQuestion
---

# /fractal:recurse

## Human gates

Every time this skill needs human input (confirmation, choice, correction), use the `AskUserQuestion` tool instead of printing the question as text output. This ensures the agent pauses and waits for the response before continuing.

Tree: $ARGUMENTS

## State (pre-loaded)

!`FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1); [ -n "$FRACTAL_SCRIPTS" ] && bash "$FRACTAL_SCRIPTS/fractal-state.sh" $ARGUMENTS 2>/dev/null || echo "state: error"`

## Predicate (pre-loaded)

!`FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1); [ -n "$FRACTAL_SCRIPTS" ] && bash "$FRACTAL_SCRIPTS/active-predicate.sh" $ARGUMENTS 2>/dev/null || echo "predicate: error"`

---

## Steps — execute in order, do not skip, do not invent steps

### 1. GUARD

- `state: error` → STOP. Print "Caminho inválido."
- `active_status: satisfied` or `pruned` → go to step 6 (ASCEND).

### 2. SHOW

Run the tree renderer and display its output:

```bash
bash "$FRACTAL_SCRIPTS/fractal-tree.sh" $ARGUMENTS
```

Then print:

```
<breadcrumb>
Predicado: <active_predicate>
Estado: <state> | Filhos: <children_satisfied>/<children_total>
```

### 3. EVALUATE

Spawn agent:

```
Agent(
  description: "evaluate: <predicate slug>",
  subagent_type: "fractal:evaluate",
  prompt: "predicate: <active_predicate>\ntree_path: $ARGUMENTS\nrepo_root: <git root>"
)
```

Wait for response. Present result to human:

- `achievable: no` → "Podar? [reasoning]"
  → Confirmed: go to step 4a (PRUNE).
  → Denied: re-run evaluate with human's context.

- `sprint_sized: yes` → "Executar: '<sub_predicate>'. [reasoning]. Aceita?"
  → Confirmed: go to step 4b (EXECUTE).
  → Rejected: ask human what they prefer.

- `sprint_sized: no` → "Recursão: '<sub_predicate>'. [reasoning]. Aceita?"
  → Confirmed: go to step 4c (RECURSE).
  → Rejected: ask human what they prefer.

### 4. TRANSITION — write to disk, then act

Every path writes state BEFORE invoking any skill or recursion.

**4a. PRUNE**

Write to active node's `predicate.md`:
- Set `status: pruned`

Go to step 6 (ASCEND).

**4b. EXECUTE (base case)**

The sub-predicate fits in one sprint. Persist execution context, then run.

1. If `same_as_input: no` — sub-predicate differs from active node:
   - Create child: `mkdir -p <node-dir>/<slug>`
   - Write `<slug>/predicate.md` with `status: pending`
   - Update `active_node` in `$ARGUMENTS/root.md`

2. Write `execution.md` in the active node dir:

```markdown
---
mode: try | sprint
sub_predicate: "<sub_predicate>"
reasoning: "<evaluator reasoning>"
created: <YYYY-MM-DD>
---
```

3. Decide execution mode:
   - **Try** if: ≤3 files, no architecture decisions, single concern, describable in 2-3 sentences.
     → Invoke `/fractal:try <sub_predicate text>`. STOP.
   - **Sprint** otherwise:
     → Invoke `/fractal:planning $ARGUMENTS`. STOP.

After execution completes → go to step 5 (VALIDATE).

**4c. RECURSE (subdivision)**

The sub-predicate is too large for one sprint. Create child node, then recurse.

1. Create child: `mkdir -p <node-dir>/<slug>`

2. Write `<slug>/predicate.md`:

```yaml
---
predicate: "<sub_predicate>"
status: pending
created: <YYYY-MM-DD>
parent_reasoning: "<evaluator reasoning>"
---
```

3. Update `active_node` in `$ARGUMENTS/root.md` to new child path.

4. Invoke `/fractal:recurse $ARGUMENTS`. STOP.

### 5. VALIDATE (post-execution)

After try or sprint completes and human has seen the result:

Ask: "Predicado satisfeito?"
- Yes → write `status: satisfied` in active node's predicate.md. Go to step 6 (ASCEND).
- No → Invoke `/fractal:recurse $ARGUMENTS`. STOP.

### 6. ASCEND (return)

Active node is satisfied or pruned. Bubble up.

6a. If active node is the tree root (`depth: 0`):
- Print "Árvore completa. Predicado raiz satisfeito." STOP.

6b. Update `active_node` in `$ARGUMENTS/root.md` to `parent_path` from state.

6c. Invoke `/fractal:recurse $ARGUMENTS`. STOP.

---

## Rules

- ONE question at a time.
- After invoking `/fractal:recurse` or any other Skill, STOP.
- ALWAYS write to disk before acting. No transition without persistence.
- Push back on vague or unfalsifiable predicates.
