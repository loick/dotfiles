# Plan: `gt` — Graphite-style stacked PR CLI + Claude skill

## Context

Replicate the Graphite CLI (`gt`) workflow for stacked PRs without using the Graphite product.

**Source of truth:** Graphite CLI behavior
- https://graphite.com/blog/stacked-prs
- https://www.graphite.com/docs/command-reference

**User workflow mirrored from Graphite 101 & 102:**
```
gt sync          → pull trunk, delete merged branches, restack
gt create --ai   → stage → AI branch name + commit → new branch stacked on current
gt modify        → amend current branch's commit → auto-restack upstack
gt ss            → push + create/update all PRs in stack
gt co            → interactive branch switch (visual tree)
gt up/down       → navigate stack one level at a time
gt top/bottom    → jump to tip or base of stack
gt restack       → rebase stack, enter conflict resolution mode
gt continue      → resume after conflict resolved
gt abort         → cancel rebase
gt move --onto   → change a branch's parent, restack children
```

**Two layers:**
- `~/bin/gt` — standalone bash script, usable in any terminal (no Claude needed)
- `~/.claude/skills/gt/SKILL.md` — Claude skill wrapping the script, adds AI features

---

## File Structure

```
~/.claude/skills/gt/
├── PLAN.md         ← this file
├── SKILL.md        ← Claude skill dispatcher
└── gt.sh           ← standalone bash script (symlinked to ~/bin/gt)
```

---

## Stack Metadata

Stored in git config — local to each repo, no extra files committed.

```bash
git config branch.<name>.gt-parent <parent>   # set
git config branch.<name>.gt-parent            # get
git config --unset branch.<name>.gt-parent    # remove

# List all gt-managed branches
git config --list | grep '\.gt-parent=' | sed 's/branch\.\(.*\)\.gt-parent=.*/\1/'

# Find children of a branch
git config --list | grep "\.gt-parent=<name>$" | sed 's/branch\.\(.*\)\.gt-parent=.*/\1/'
```

Trunk detection (first match): `gt.trunk` git config → `main` → `master` → `develop`.

---

## `gt.sh` — Shell Commands

### `gt sync`
1. `git fetch origin`
2. `git checkout <trunk> && git pull`
3. For each gt-managed branch: check `gh pr view <b> --json state -q .state`
   - `MERGED` or `CLOSED` → `git branch -D <b>`, remove gt-parent config
4. Auto-restack surviving branches bottom-up

### `gt create [-a] [-m "msg"] [branch-name]`
1. Record `PARENT=$(git branch --show-current)`
2. Branch name from arg, or slugify `-m` value
3. `git checkout -b <name>`
4. If `-a`: `git add -A`
5. `git commit -m "<msg>"`
6. `git config branch.<name>.gt-parent <PARENT>`

`--ai` flag → Claude skill only (not in shell script)

### `gt modify [-a] [-c] [-m "msg"]`
1. If `-a`: `git add -A`
2. If `-c`: new commit; else `git commit --amend [--no-edit | -m]`
3. Auto-restack all upstack branches

### `gt submit` / `gt ss` `[-u] [--publish] [-mp]`
Bottom-up for each branch in stack:
1. `git push origin <b> --force-with-lease`
2. No PR → `gh pr create --base <parent> --head <b> --fill`
3. PR exists → `gh pr edit <b> --base <parent>` (ensures base stays correct)
4. `--publish` → `gh pr ready <b>`
5. `-mp` → `gh pr merge --auto --squash <b>`

PR title/body in shell script: `--fill`. AI-generated: Claude skill.

### `gt checkout` / `gt co [name]`
- With arg: `git checkout <name>`
- No arg: print visual stack tree → prompt for branch number

```
  develop
  └── feat/auth          (PR #12 · open)
        └── feat/dashboard  (PR #13 · draft)
              └── feat/charts  (no PR yet)  ← current

  1) develop
  2) feat/auth
  3) feat/dashboard
  4) feat/charts
Switch to [1-4]:
```

### `gt up [n]` / `gt down [n]` / `gt top` / `gt bottom`
- `up n`: walk gt-parent n times → checkout
- `down n`: find child n levels deep (prompt if multiple children)
- `top`: walk until no children → checkout
- `bottom`: walk gt-parent until parent = trunk → checkout

### `gt restack`
For each branch bottom-up:
1. `PARENT=$(git config branch.<b>.gt-parent)`
2. `PARENT_HEAD=$(git rev-parse $PARENT)`
3. `MERGE_BASE=$(git merge-base $b $PARENT)`
4. If `MERGE_BASE != PARENT_HEAD`: `git rebase $PARENT $b`
5. On conflict: save remaining queue to `/tmp/gt-restack-queue`, print instructions, exit

### `gt continue`
`git rebase --continue` → resume pending restack queue from `/tmp/gt-restack-queue`

### `gt abort`
`git rebase --abort` → clear `/tmp/gt-restack-queue`

### `gt move [--onto <target>]`
1. `OLD_PARENT=$(git config branch.<current>.gt-parent)`
2. `git rebase --onto <target> $OLD_PARENT`
3. `git config branch.<current>.gt-parent <target>`
4. Restack children

---

## Claude Skill Additions (SKILL.md)

Intercepts AI-specific paths before delegating to `gt.sh`:

| Command | AI addition |
|---|---|
| `gt create --ai` | Read `git diff HEAD`, propose branch name + commit msg, confirm, then call `gt create -m "..." <name>` |
| `gt submit` (new PR) | After push, Claude writes PR title + body from diff, confirms, then `gh pr create --title "..." --body "..."` |
| `gt co` (no args) | Claude builds + displays visual tree, asks which branch |

---

## Installation

```bash
mkdir -p ~/bin
ln -sf ~/.claude/skills/gt/gt.sh ~/bin/gt
chmod +x ~/.claude/skills/gt/gt.sh
# Add to ~/.zshrc if ~/bin not in PATH:
# export PATH="$HOME/bin:$PATH"
```

---

## Verification Checklist

- [ ] `gt create -am "test: hello"` → branch created, git config set
- [ ] `gt up` / `gt down` → navigation works
- [ ] `gt modify -a` → amend + restack upstack
- [ ] `gt submit` → PR created with correct base
- [ ] `gt sync` → merged branches deleted, surviving branches restacked
- [ ] `~/bin/gt sync` works from terminal without Claude
