---
name: stacked-prs
description: Manage stacked pull requests, dependent branches, rebases, stack updates, and ordered merges. Also use proactively when creating a PR — if changes are large, split them into a stack.
allowed-tools:
  - bash
  - git
  - gh
---

# Stacked PRs with spr

Use this skill when working on a branch stack where later branches depend on earlier branches.

This skill uses `spr` (Stacked Pull Requests) — each commit on the branch becomes a PR, and the tool manages the stack automatically.

## Core Commands

| Command | Alias | Purpose |
|---------|-------|---------|
| `git spr update` | `u`, `up` | Create/update PRs for all commits in stack |
| `git spr status` | `s`, `st` | Show stack status with merge-readiness bits |
| `git spr merge` | — | Merge all mergeable PRs from bottom up |
| `git spr amend` | `a` | Amend a commit anywhere in the stack |
| `git spr edit` | `e` | Interactive rebase for editing a specific commit |
| `git spr sync` | — | Sync local stack with remote |

## Workflow

1. Make commits normally — each commit becomes a PR.
2. Run `git spr update` to create/update all PRs in the stack.
3. Check status with `git spr status`.
4. When reviews pass, run `git spr merge` to merge from the bottom up.
5. After merging, `git spr sync` to align local state.

### Amending a commit in the stack

1. Stage changes.
2. Run `git spr amend` — select the target commit.
3. Run `git spr update` to push changes (or use `git spr amend --update`).

### WIP commits

Prefix a commit message with "WIP" to prevent PR creation until you remove the prefix and run `git spr update`.

### Starting a new stack

```bash
git checkout -b new_stack @{push}
```

## PR Size Gate — Proactive Splitting

**This is the most important rule.** Before creating any PR, check if it should be a stack.

### When to split

When the user asks to create a PR, run `git diff --stat main` (or the base branch) and count meaningful changed lines — **exclude lock files and generated files** (e.g. `yarn.lock`, `package-lock.json`, `pnpm-lock.yaml`, `*.generated.*`, migration snapshots).

- **<= 200 lines**: ship as a single PR.
- **> 200 lines**: propose a split into a stack. Each PR in the stack should be <= 200 lines of meaningful changes.

### How to split

1. Analyze the diff and identify logical, independently reviewable units. Good split boundaries:
   - New types/interfaces/schemas first, then code that uses them.
   - Backend changes (API, DB) before frontend changes that consume them.
   - Refactors/renames before feature code.
   - Test infrastructure before tests before implementation.
   - Each independent module or concern gets its own commit.
2. Present the proposed split to the user for approval — list each commit with a title and rough line count.
3. Once approved, create the commits in dependency order (bottom of stack = merged first).
4. Run `git spr update` to create all PRs at once.

### Important

- The user builds and iterates with all changes at once. Splitting happens at PR creation time, not during development.
- Each commit in the stack must leave the codebase in a valid, buildable state.
- Commit message subject = PR title, body = PR description. Make them clear about what this slice does and where it sits in the stack.

## Goals

- Keep each PR small and reviewable (target <= 200 lines, excluding generated files).
- Preserve stack order — spr handles rebasing automatically.
- Open, update, and merge PRs in dependency order.

## Rules

- **Proactively check PR size before creating any PR.** Never ship a 500-line PR as a single commit when it can be a clean stack.
- Never merge a dependent PR before its parent — always merge from the bottom of the stack upward.
- Never merge via GitHub UI — use `git spr merge` so ordering is preserved.
- Prefer `git spr update` over manual `git push`.
- Prefer rebasing over merging main into stack branches (spr does this by default).
- Keep commit messages clean — the subject becomes the PR title, the body becomes the PR description.
- Ask for confirmation before force-pushing or merging if the action is risky.
- Use `--count` flag to partially merge or update a subset of the stack.

## Status Bits

Each PR in `git spr status` shows 4 indicators:

| Position | Meaning | Pass | Fail | Pending | N/A |
|----------|---------|------|------|---------|-----|
| 1 | CI checks | ✅ | ❌ | ⌛ | ➖ |
| 2 | Approval | ✅ | ❌ | — | ➖ |
| 3 | Conflicts | ✅ | ❌ | — | — |
| 4 | Stack below | ✅ | ❌ | — | — |

All required bits must be ✅ before merging.

## Output Format

When reporting status, include:
- Current stack order.
- Branch currently being worked on.
- PRs blocked by upstream changes.
- Any required rebases or force-pushes.

---
  Gotchas

  commit-id lines are sacred

  spr identifies commits by the commit-id:xxx line in the commit body. If these are missing, git spr update treats the stack as empty and will reset your branch to
  origin/main, silently losing all commits.

  After any manual git rebase, always verify:
  git log --format=%B origin/main..HEAD | grep commit-id

  If commit-ids were stripped, restore them via an edit rebase:
  GIT_SEQUENCE_EDITOR="sed -i '' 's/^pick /edit /g'" git rebase -i origin/main
  # Then for each commit:
  git commit --amend  # add the commit-id line back
  git rebase --continue

  If commit-ids were duplicated (old + new), remove the extras the same way. Always keep the original commit-id that matches the existing PR.

  Multi-commit changes (renames, shared file edits)

  When a change touches multiple commits in the stack (e.g. renaming a file imported across several commits), never amend one commit at a time — intermediate states will have
  broken imports and cause rebase conflicts.

  Instead, create all fixup commits first, then squash in a single rebase:
  git add <files-for-commit-A> && git commit --fixup <hash-A>
  git add <files-for-commit-B> && git commit --fixup <hash-B>
  git add <files-for-commit-C> && git commit --fixup <hash-C>
  # Then one rebase to squash them all:
  git rebase -i --autosquash origin/main

  Don't use git rebase --exec with git commit --amend

  The amend rewrites the commit, which leaves the working tree in a "dirty" state that blocks the rebase from continuing. Use edit mode and amend each commit manually instead.

