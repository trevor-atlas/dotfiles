#!/bin/zsh

_zwt_impl() {
    local branch_name=""
    local skip_pull=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-pull|-n)
                skip_pull=true
                shift
                ;;
            -*)
                echo "Unknown option: $1" >&2
                echo "Usage: zwt <branch-name> [--no-pull|-n]" >&2
                return 1
                ;;
            *)
                if [[ -z "$branch_name" ]]; then
                    branch_name="$1"
                else
                    echo "Too many arguments" >&2
                    echo "Usage: zwt <branch-name> [--no-pull|-n]" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$branch_name" ]]; then
        echo "Usage: zwt <branch-name> [--no-pull|-n]" >&2
        echo "  --no-pull, -n    Skip pulling latest master" >&2
        return 1
    fi

    # Get current repo name
    local repo_name
    repo_name=$(basename "$(git rev-parse --show-toplevel)")
    if [[ $? -ne 0 ]]; then
        echo "Failed to get repository root" >&2
        return 1
    fi

    local worktree_name="${repo_name}__${branch_name}"

    # Configure branch prefix (can be set via environment variable)
    local branch_prefix="${ZWT_BRANCH_PREFIX:-}"
    local full_branch_name
    if [[ -n "$branch_prefix" ]]; then
        full_branch_name="${branch_prefix}/${branch_name}"
    else
        full_branch_name="$branch_name"
    fi

    # Get base branch (configurable via environment variable, or auto-detect)
    local base_branch="${ZWT_BASE_BRANCH:-}"
    if [[ -z "$base_branch" ]]; then
        # Try to detect the default branch
        if git rev-parse --verify main >/dev/null 2>&1; then
            base_branch="main"
        elif git rev-parse --verify master >/dev/null 2>&1; then
            base_branch="master"
        elif git symbolic-ref refs/remotes/origin/HEAD >/dev/null 2>&1; then
            # Get the default branch from remote
            base_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
        else
            # Fallback to current branch if nothing else works
            base_branch=$(git branch --show-current)
            if [[ -z "$base_branch" ]]; then
                echo "Error: Could not determine base branch. Please set ZWT_BASE_BRANCH environment variable." >&2
                return 1
            fi
        fi
    fi

    # Check if branch name conflicts with base branch
    if [[ "$full_branch_name" == "$base_branch" ]]; then
        echo "Error: Branch name cannot be '$base_branch' (conflicts with base branch)" >&2
        echo "Either use a different name or set ZWT_BRANCH_PREFIX to add a prefix" >&2
        return 1
    fi

    # Check if base branch exists and has commits
    if ! git rev-parse --verify "$base_branch" >/dev/null 2>&1; then
        echo "Error: Base branch '$base_branch' does not exist or has no commits" >&2
        echo "Make sure you have at least one commit on the base branch" >&2
        return 1
    fi

    # Update base branch unless --no-pull flag is passed
    if [[ "$skip_pull" == false ]]; then
        echo "Updating $base_branch..."
        if ! (git checkout "$base_branch" && git pull); then
            echo "Failed to update $base_branch" >&2
            return 1
        fi
    fi

    # Create worktree
    if git worktree add "../$worktree_name" -b "$full_branch_name" "$base_branch"; then
        echo "Created worktree: $worktree_name"
        echo "Branch name: $full_branch_name"
        echo "cd ../$worktree_name"
        cd "../$worktree_name" || return 1
    else
        echo "Failed to create worktree" >&2
        return 1
    fi
}

zwt() {
    _zwt_impl "$@"
}

new-worktree() {
    _zwt_impl "$@"
}

nwt() {
    _zwt_impl "$@"
}
