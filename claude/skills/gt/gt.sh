#!/usr/bin/env bash
# gt — Graphite-style stacked PR CLI
# Standalone bash script. No Claude required.
# Usage: gt <command> [args]
# Symlink to ~/bin/gt for terminal use.

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() { echo "gt: error: $*" >&2; exit 1; }
info() { echo "gt: $*"; }

get_trunk() {
  git config gt.trunk 2>/dev/null && return
  for b in main master develop; do
    if git show-ref --verify --quiet "refs/heads/$b"; then
      echo "$b"; return
    fi
  done
  die "could not detect trunk branch (set with: git config gt.trunk <branch>)"
}

current_branch() {
  git branch --show-current
}

gt_parent() {
  git config "branch.$1.gt-parent" 2>/dev/null || true
}

set_gt_parent() {
  git config "branch.$1.gt-parent" "$2"
}

unset_gt_parent() {
  git config --unset "branch.$1.gt-parent" 2>/dev/null || true
}

# All gt-managed branches
gt_branches() {
  git config --list 2>/dev/null \
    | grep '\.gt-parent=' \
    | sed 's/branch\.\(.*\)\.gt-parent=.*/\1/'
}

# Direct children of a branch
gt_children() {
  local parent="$1"
  git config --list 2>/dev/null \
    | grep "\.gt-parent=${parent}$" \
    | sed 's/branch\.\(.*\)\.gt-parent=.*/\1/'
}

# Return branches in bottom-up order (parents before children)
gt_branches_sorted() {
  local trunk
  trunk=$(get_trunk)
  local all
  all=$(gt_branches)
  [ -z "$all" ] && return

  # Topological sort: repeatedly emit branches whose parent is already emitted
  local emitted="$trunk"
  local remaining="$all"
  local changed=1
  while [ "$changed" = "1" ] && [ -n "$remaining" ]; do
    changed=0
    local new_remaining=""
    while IFS= read -r b; do
      local p
      p=$(gt_parent "$b")
      if echo "$emitted" | grep -qx "$p" 2>/dev/null; then
        echo "$b"
        emitted="$emitted"$'\n'"$b"
        changed=1
      else
        new_remaining="$new_remaining"$'\n'"$b"
      fi
    done <<< "$remaining"
    remaining="$new_remaining"
  done

  # Emit any remaining (orphaned) branches
  if [ -n "$remaining" ]; then
    while IFS= read -r b; do
      [ -n "$b" ] && echo "$b"
    done <<< "$remaining"
  fi
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9/-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

pr_state() {
  local branch="$1"
  gh pr view "$branch" --json state -q .state 2>/dev/null || echo "NONE"
}

pr_number() {
  local branch="$1"
  gh pr view "$branch" --json number -q .number 2>/dev/null || echo ""
}

pr_status_label() {
  local branch="$1"
  local state num
  state=$(gh pr view "$branch" --json state,isDraft -q '"\(.state)|\(.isDraft)"' 2>/dev/null || echo "")
  if [ -z "$state" ]; then
    echo "no PR yet"
    return
  fi
  local s d
  s=$(echo "$state" | cut -d'|' -f1)
  d=$(echo "$state" | cut -d'|' -f2)
  num=$(pr_number "$branch")
  if [ "$s" = "MERGED" ]; then echo "PR #$num · merged"
  elif [ "$s" = "CLOSED" ]; then echo "PR #$num · closed"
  elif [ "$d" = "true" ]; then echo "PR #$num · draft"
  else echo "PR #$num · open"
  fi
}

# ---------------------------------------------------------------------------
# Restack engine
# ---------------------------------------------------------------------------

# Restack a single branch onto its parent. Returns 0 on success, 1 on conflict.
restack_one() {
  local b="$1"
  local parent
  parent=$(gt_parent "$b")
  [ -z "$parent" ] && return 0

  local parent_head merge_base
  parent_head=$(git rev-parse "$parent")
  merge_base=$(git merge-base "$b" "$parent" 2>/dev/null || true)

  if [ "$merge_base" = "$parent_head" ]; then
    return 0  # already up to date
  fi

  info "restacking $b onto $parent ..."
  if ! git rebase "$parent" "$b"; then
    return 1  # conflict
  fi
  return 0
}

# Restack all branches bottom-up from a given list.
# On conflict, saves remaining queue to /tmp/gt-restack-queue and exits.
restack_list() {
  local queue=("$@")
  local i=0
  for b in "${queue[@]}"; do
    if ! restack_one "$b"; then
      echo "gt: rebase conflict on $b" >&2
      echo "Resolve conflicts, then run: gt continue" >&2
      echo "Or cancel with: gt abort" >&2
      # Save remaining branches (starting from current)
      printf '%s\n' "${queue[@]:$i}" > /tmp/gt-restack-queue
      exit 1
    fi
    (( i++ )) || true
  done
}

# Restack all gt-managed branches bottom-up
restack_all() {
  local sorted
  sorted=$(gt_branches_sorted)
  [ -z "$sorted" ] && return 0
  local queue=()
  while IFS= read -r b; do
    [ -n "$b" ] && queue+=("$b")
  done <<< "$sorted"
  restack_list "${queue[@]}"
}

# Restack only the upstack branches of a given branch
restack_upstack() {
  local root="$1"
  local all_sorted
  all_sorted=$(gt_branches_sorted)
  [ -z "$all_sorted" ] && return 0

  # Collect descendants of root
  local descendants=()
  collect_descendants() {
    local parent="$1"
    while IFS= read -r child; do
      [ -n "$child" ] || continue
      descendants+=("$child")
      collect_descendants "$child"
    done < <(gt_children "$parent")
  }
  collect_descendants "$root"

  [ "${#descendants[@]}" -eq 0 ] && return 0

  # Filter all_sorted to only descendants (preserving order)
  local queue=()
  while IFS= read -r b; do
    for d in "${descendants[@]}"; do
      if [ "$b" = "$d" ]; then
        queue+=("$b")
        break
      fi
    done
  done <<< "$all_sorted"

  [ "${#queue[@]}" -eq 0 ] && return 0
  restack_list "${queue[@]}"
}

# ---------------------------------------------------------------------------
# Visual tree
# ---------------------------------------------------------------------------

# Print a visual tree rooted at trunk, showing stacked branches.
print_stack_tree() {
  local trunk current
  trunk=$(get_trunk)
  current=$(current_branch)

  # Collect all branches for numbering
  TREE_NUMBERED=()

  _print_node() {
    local branch="$1"
    local prefix="$2"
    local is_last="$3"
    local connector child_prefix

    TREE_NUMBERED+=("$branch")
    local idx="${#TREE_NUMBERED[@]}"

    local marker=""
    [ "$branch" = "$current" ] && marker=" ← current"

    local label
    if [ "$branch" = "$trunk" ]; then
      label="$branch"
    else
      local status
      status=$(pr_status_label "$branch")
      label="$branch  ($status)$marker"
    fi

    if [ "$branch" = "$trunk" ]; then
      echo "  $label"
    else
      if [ "$is_last" = "1" ]; then
        connector="└── "
        child_prefix="      "
      else
        connector="├── "
        child_prefix="│     "
      fi
      echo "  ${prefix}${connector}${label}"
    fi

    local children=()
    while IFS= read -r c; do
      [ -n "$c" ] && children+=("$c")
    done < <(gt_children "$branch")

    local n="${#children[@]}"
    local ci=0
    for child in "${children[@]}"; do
      ci=$(( ci + 1 ))
      local last=0
      [ "$ci" -eq "$n" ] && last=1
      if [ "$branch" = "$trunk" ]; then
        _print_node "$child" "  " "$last"
      else
        _print_node "$child" "${prefix}${child_prefix}" "$last"
      fi
    done
  }

  _print_node "$trunk" "" "1"
  echo ""

  local i=0
  for b in "${TREE_NUMBERED[@]}"; do
    i=$(( i + 1 ))
    echo "  $i) $b"
  done
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_sync() {
  local trunk
  trunk=$(get_trunk)

  info "fetching origin ..."
  git fetch origin

  info "updating $trunk ..."
  git checkout "$trunk"
  git pull

  info "checking PR states ..."
  local managed
  managed=$(gt_branches)
  if [ -n "$managed" ]; then
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      local state
      state=$(pr_state "$b")
      if [ "$state" = "MERGED" ] || [ "$state" = "CLOSED" ]; then
        info "deleting $b ($state) ..."
        git branch -D "$b" 2>/dev/null || true
        unset_gt_parent "$b"
      fi
    done <<< "$managed"
  fi

  info "restacking surviving branches ..."
  restack_all
  info "sync complete."
}

cmd_create() {
  local do_add=0 msg="" branch_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a) do_add=1; shift ;;
      -m) msg="$2"; shift 2 ;;
      --) shift; break ;;
      -*) die "unknown flag: $1" ;;
      *)  branch_name="$1"; shift ;;
    esac
  done

  local parent
  parent=$(current_branch)

  if [ -z "$branch_name" ]; then
    [ -z "$msg" ] && die "branch name or -m <msg> required"
    branch_name=$(slugify "$msg")
  fi

  [ -z "$msg" ] && die "-m <msg> required"

  info "creating branch $branch_name from $parent ..."
  git checkout -b "$branch_name"

  if [ "$do_add" = "1" ]; then
    git add -A
  fi

  git commit -m "$msg"
  set_gt_parent "$branch_name" "$parent"
  info "branch $branch_name stacked on $parent."
}

cmd_modify() {
  local do_add=0 new_commit=0 msg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a) do_add=1; shift ;;
      -c) new_commit=1; shift ;;
      -m) msg="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done

  local branch
  branch=$(current_branch)

  if [ "$do_add" = "1" ]; then
    git add -A
  fi

  if [ "$new_commit" = "1" ]; then
    if [ -n "$msg" ]; then
      git commit -m "$msg"
    else
      git commit
    fi
  else
    if [ -n "$msg" ]; then
      git commit --amend -m "$msg"
    else
      git commit --amend --no-edit
    fi
  fi

  info "restacking upstack branches ..."
  restack_upstack "$branch"
  info "modify complete."
}

cmd_submit() {
  local do_update=0 do_publish=0 do_merge=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -u) do_update=1; shift ;;
      --publish) do_publish=1; shift ;;
      -mp) do_merge=1; shift ;;
      *) die "unknown flag: $1" ;;
    esac
  done

  local trunk current
  trunk=$(get_trunk)
  current=$(current_branch)

  # Build list: trunk → current path (bottom-up), excluding trunk
  local stack=()
  local b="$current"
  while [ "$b" != "$trunk" ] && [ -n "$b" ]; do
    stack=("$b" "${stack[@]+"${stack[@]}"}")
    b=$(gt_parent "$b")
    [ -z "$b" ] && break
  done

  [ "${#stack[@]}" -eq 0 ] && die "no stacked branches to submit (are you on trunk?)"

  for b in "${stack[@]}"; do
    local parent
    parent=$(gt_parent "$b")
    [ -z "$parent" ] && parent="$trunk"

    info "pushing $b ..."
    git push origin "$b" --force-with-lease

    local state
    state=$(pr_state "$b")
    if [ "$state" = "NONE" ]; then
      info "creating PR for $b (base: $parent) ..."
      gh pr create --base "$parent" --head "$b" --fill
    else
      info "updating PR base for $b → $parent ..."
      gh pr edit "$b" --base "$parent"
    fi

    if [ "$do_publish" = "1" ]; then
      gh pr ready "$b" || true
    fi

    if [ "$do_merge" = "1" ]; then
      gh pr merge --auto --squash "$b" || true
    fi
  done

  info "submit complete."
}

cmd_checkout() {
  if [ $# -gt 0 ]; then
    git checkout "$1"
    return
  fi

  # Interactive: print tree and prompt
  TREE_NUMBERED=()
  print_stack_tree

  local count="${#TREE_NUMBERED[@]}"
  [ "$count" -eq 0 ] && die "no branches in stack"

  printf "Switch to [1-%d]: " "$count"
  local choice
  read -r choice

  [[ "$choice" =~ ^[0-9]+$ ]] || die "invalid choice"
  [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ] || die "out of range"

  local target="${TREE_NUMBERED[$(( choice - 1 ))]}"
  git checkout "$target"
}

cmd_up() {
  local n="${1:-1}"
  local b
  b=$(current_branch)
  local i=0
  while [ "$i" -lt "$n" ]; do
    local children=()
    while IFS= read -r c; do
      [ -n "$c" ] && children+=("$c")
    done < <(gt_children "$b")

    if [ "${#children[@]}" -eq 0 ]; then
      info "already at top of stack."
      break
    elif [ "${#children[@]}" -eq 1 ]; then
      b="${children[0]}"
    else
      echo "Multiple children:"
      local j=0
      for c in "${children[@]}"; do
        j=$(( j + 1 ))
        echo "  $j) $c"
      done
      printf "Choose [1-%d]: " "${#children[@]}"
      local pick
      read -r pick
      b="${children[$(( pick - 1 ))]}"
    fi
    i=$(( i + 1 ))
  done
  git checkout "$b"
}

cmd_down() {
  local n="${1:-1}"
  local trunk
  trunk=$(get_trunk)
  local b
  b=$(current_branch)
  local i=0
  while [ "$i" -lt "$n" ]; do
    local parent
    parent=$(gt_parent "$b")
    if [ -z "$parent" ] || [ "$b" = "$trunk" ]; then
      info "already at bottom of stack."
      break
    fi
    b="$parent"
    i=$(( i + 1 ))
  done
  git checkout "$b"
}

cmd_top() {
  local b
  b=$(current_branch)
  while true; do
    local children=()
    while IFS= read -r c; do
      [ -n "$c" ] && children+=("$c")
    done < <(gt_children "$b")

    if [ "${#children[@]}" -eq 0 ]; then
      break
    elif [ "${#children[@]}" -eq 1 ]; then
      b="${children[0]}"
    else
      echo "Multiple children at $b:"
      local j=0
      for c in "${children[@]}"; do
        j=$(( j + 1 ))
        echo "  $j) $c"
      done
      printf "Choose [1-%d]: " "${#children[@]}"
      local pick
      read -r pick
      b="${children[$(( pick - 1 ))]}"
    fi
  done
  git checkout "$b"
}

cmd_bottom() {
  local trunk
  trunk=$(get_trunk)
  local b
  b=$(current_branch)
  while true; do
    local parent
    parent=$(gt_parent "$b")
    if [ -z "$parent" ] || [ "$parent" = "$trunk" ] || [ "$b" = "$trunk" ]; then
      break
    fi
    b="$parent"
  done
  git checkout "$b"
}

cmd_restack() {
  restack_all
  info "restack complete."
}

cmd_continue() {
  if ! git rebase --continue; then
    die "rebase --continue failed. Resolve conflicts and try again."
  fi

  if [ ! -f /tmp/gt-restack-queue ]; then
    info "rebase complete, no pending restack queue."
    return
  fi

  local queue=()
  while IFS= read -r b; do
    [ -n "$b" ] && queue+=("$b")
  done < /tmp/gt-restack-queue

  # Remove first entry (was the branch that conflicted — now resumed)
  if [ "${#queue[@]}" -gt 1 ]; then
    queue=("${queue[@]:1}")
    restack_list "${queue[@]}"
  fi

  rm -f /tmp/gt-restack-queue
  info "restack complete."
}

cmd_abort() {
  git rebase --abort || true
  rm -f /tmp/gt-restack-queue
  info "rebase aborted, restack queue cleared."
}

cmd_move() {
  local target=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --onto) target="$2"; shift 2 ;;
      *) die "unknown argument: $1" ;;
    esac
  done

  [ -z "$target" ] && die "--onto <target> required"

  local current old_parent
  current=$(current_branch)
  old_parent=$(gt_parent "$current")
  [ -z "$old_parent" ] && die "$current has no gt-parent set"

  info "rebasing $current onto $target (was on $old_parent) ..."
  git rebase --onto "$target" "$old_parent"
  set_gt_parent "$current" "$target"

  info "restacking children of $current ..."
  restack_upstack "$current"
  info "move complete."
}

# --list flag for SKILL.md co integration
cmd_co_list() {
  local trunk
  trunk=$(get_trunk)
  local current
  current=$(current_branch)
  echo "TRUNK=$trunk"
  echo "CURRENT=$current"
  gt_branches_sorted | while IFS= read -r b; do
    [ -n "$b" ] || continue
    local parent status_label
    parent=$(gt_parent "$b")
    status_label=$(pr_status_label "$b")
    echo "BRANCH=$b PARENT=${parent} STATUS=${status_label}"
  done
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

main() {
  [ $# -eq 0 ] && { echo "Usage: gt <command> [args]"; exit 1; }

  local cmd="$1"; shift

  case "$cmd" in
    sync)     cmd_sync "$@" ;;
    create)   cmd_create "$@" ;;
    modify)   cmd_modify "$@" ;;
    submit|ss) cmd_submit "$@" ;;
    checkout|co)
      if [ "${1:-}" = "--list" ]; then
        cmd_co_list
      else
        cmd_checkout "$@"
      fi
      ;;
    up)       cmd_up "${1:-1}" ;;
    down)     cmd_down "${1:-1}" ;;
    top)      cmd_top ;;
    bottom)   cmd_bottom ;;
    restack)  cmd_restack ;;
    continue) cmd_continue ;;
    abort)    cmd_abort ;;
    move)     cmd_move "$@" ;;
    *)        die "unknown command: $cmd" ;;
  esac
}

main "$@"
