---
name: gt
description: Graphite-style stacked PR workflow. Use when user invokes /gt or gt commands (gt create --ai, gt submit, gt co, gt sync, gt modify, gt up, gt down, etc.)
---

# gt Skill

Stacked PR workflow backed by `~/.claude/skills/gt/gt.sh`. Most commands delegate directly to the shell script. A few get AI enhancement.

## Dispatch table

| Command | Handling |
|---|---|
| `gt sync` | Shell script |
| `gt restack` | Shell script |
| `gt continue` | Shell script |
| `gt abort` | Shell script |
| `gt up [n]` | Shell script |
| `gt down [n]` | Shell script |
| `gt top` | Shell script |
| `gt bottom` | Shell script |
| `gt move --onto <target>` | Shell script |
| `gt create` (no `--ai`) | Shell script |
| `gt modify` | Shell script |
| `gt create --ai` | AI-enhanced (below) |
| `gt submit` / `gt ss` | AI-enhanced for new PRs (below) |
| `gt co` (no args) | AI-enhanced (below) |

---

## Shell-only commands

For the commands in the "Shell script" category above, run the shell script directly via Bash tool:

```
~/.claude/skills/gt/gt.sh <command> <args>
```

Show output to user as-is. If exit code is non-zero, display the error and suggest:
- Conflict errors: "Resolve the conflicts in the listed files, then run `gt continue`. Run `gt abort` to cancel."
- Other errors: show the raw error and ask the user how to proceed.

---

## AI-enhanced: `gt create --ai`

**Goal:** Inspect staged/unstaged changes, propose a branch name and commit message, confirm with user, then create the branch.

**Steps:**

1. Run these via Bash tool in parallel:
   - `git diff HEAD`
   - `git status --short`

2. Analyze the diff. Generate:
   - **Branch name**: kebab-case, max 40 chars, prefixed with conventional type (`feat/`, `fix/`, `chore/`, `refactor/`, `test/`, `docs/`). Example: `feat/add-user-auth`
   - **Commit message**: conventional commit format. Example: `feat(auth): add JWT login endpoint`

3. Show the user:
   ```
   Proposed branch: feat/add-user-auth
   Proposed commit: feat(auth): add JWT login endpoint

   Confirm? [y/n/edit]
   ```
   - `y` → proceed
   - `n` → abort
   - `edit` → ask user to provide their preferred branch name and/or message

4. Run via Bash tool:
   ```
   ~/.claude/skills/gt/gt.sh create -a -m "<commit-msg>" <branch-name>
   ```

---

## AI-enhanced: `gt submit` / `gt ss`

**Goal:** Push all branches in the current stack, creating AI-written PRs for any that don't have one yet.

**Steps:**

1. Run via Bash tool to understand the stack and PR states:
   ```bash
   git branch --show-current
   # Then for each branch in the stack path, check:
   gh pr view <branch> --json state,number,title 2>/dev/null || echo "NO_PR"
   ```

2. For branches **with existing PRs**: delegate entirely to shell script:
   ```
   ~/.claude/skills/gt/gt.sh submit <flags>
   ```

3. For branches **without a PR** (new PRs only):
   a. Push first:
      ```
      git push origin <branch> --force-with-lease
      ```
   b. Get the diff for this branch relative to its parent:
      ```
      git log <parent>..<branch> --oneline
      git diff <parent>..<branch>
      ```
   c. Generate:
      - **PR title**: ≤70 chars, conventional commit style
      - **PR body**: markdown with two sections:
        ```
        ## Summary
        - <bullet 1>
        - <bullet 2>

        ## Test plan
        - [ ] <test step 1>
        - [ ] <test step 2>
        ```
   d. Show the user the title and body for confirmation before creating.
   e. After confirmation:
      ```
      gh pr create --base <parent> --head <branch> --title "<title>" --body "<body>"
      ```
   f. If `--publish` flag: `gh pr ready <branch>`
   g. If `-mp` flag: `gh pr merge --auto --squash <branch>`

4. Process branches bottom-up (closest to trunk first).

---

## AI-enhanced: `gt co` (no args)

**Goal:** Display a visual stack tree and let the user pick a branch interactively.

**Steps:**

1. Run via Bash tool:
   ```
   ~/.claude/skills/gt/gt.sh co --list
   ```
   This outputs structured lines: `TRUNK=...`, `CURRENT=...`, `BRANCH=... PARENT=... STATUS=...`

2. Parse the output and build a visual tree. Display it in this format:
   ```
     trunk
     └── feat/auth          (PR #12 · open)
           └── feat/dashboard  (PR #13 · draft)
                 └── feat/charts  (no PR yet)  ← current

     1) trunk
     2) feat/auth
     3) feat/dashboard
     4) feat/charts
   ```

3. Ask: `Switch to [1-N]:`

4. On user input, run via Bash tool:
   ```
   git checkout <chosen-branch>
   ```

---

## Error handling

- Non-zero exit from shell script → show stderr output clearly, prefixed with `gt error:`
- Rebase conflict → always suggest: "`gt continue` after resolving, or `gt abort` to cancel"
- `gh` not found → suggest: `brew install gh && gh auth login`
- No gt-managed branches → suggest: `gt create --ai` to start a stack
