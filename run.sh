#!/bin/bash
# run.sh - Auto-run Claude Code on GitHub issues overnight
#
# ============================================================================
# OVERVIEW
# ============================================================================
# This script orchestrates automated issue resolution by:
# 1. Scanning open GitHub issues
# 2. Creating implementation plans via Claude Code skills
# 3. Implementing fixes when approved
# 4. Creating draft PRs
# 5. Updating PRs based on review feedback
#
# ============================================================================
# WORKFLOW DIAGRAM
# ============================================================================
#
#   Open Issue (no plan)
#        │
#        ▼
#   ┌─────────────────┐
#   │ stage_plan()    │ ← Claude reads code, generates visual plan
#   │ Posts comment   │   with diagrams, posts to GitHub
#   └────────┬────────┘
#            │
#            ▼
#   User reviews plan
#            │
#            ▼ "LGTM"
#   ┌──────────────────────┐
#   │ stage_implement()    │ ← Creates worktree, Claude implements,
#   │ Creates draft PR     │   commits frequently, pushes branch
#   └────────┬─────────────┘
#            │
#            ▼
#   User reviews PR
#            │
#            ▼ Review comments
#   ┌──────────────────────┐
#   │ stage_update_pr()    │ ← Claude reads feedback, makes changes,
#   │ Pushes updates       │   pushes updates
#   └────────┬─────────────┘
#            │
#            ▼
#   User merges PR → Issue closed
#
# ============================================================================
# STATE DETECTION
# ============================================================================
# The script determines what action to take by checking:
#
#   has_plan()      → Looks for <!-- NIGHT_RUNNER_PLAN --> in comments
#   has_lgtm()      → Searches for "LGTM" reply (case insensitive)
#   has_pr()        → Queries gh pr list --search "fixes #123"
#   pr_has_new_comments() → Checks for review comments on PR
#
# State transitions:
#   NO_PLAN → POST_PLAN → WAITING_LGTM → IMPLEMENT → PR_CREATED → UPDATE_PR
#
# ============================================================================
# GIT WORKTREE STRATEGY
# ============================================================================
# Uses git worktree to isolate each issue's work:
#
#   Main repo: ~/project/connectonion/  (stays on main, untouched)
#        │
#        ├─> Worktree: ~/worktrees/connectonion-123/  (night-runner/123)
#        └─> Worktree: ~/worktrees/connectonion-456/  (night-runner/456)
#
# Benefits:
#   - Parallel work on multiple issues
#   - No branch switching in main repo
#   - Isolated environments
#   - Easy cleanup (just remove directory)
#
# ============================================================================
# CLAUDE CODE SKILLS
# ============================================================================
# Invokes skills via symlinks in ~/.claude/skills/:
#
#   /night-runner-plan {issue_number}
#     ├─> Fetches issue via gh
#     ├─> Reads related code
#     ├─> Generates plan with ASCII diagrams
#     └─> Returns markdown
#
#   /night-runner-implement {issue_number}
#     ├─> Reads issue details
#     ├─> Implements fix
#     ├─> Makes frequent commits
#     └─> Final commit: "fixes #{issue_number}"
#
#   /night-runner-update-pr {pr_number}
#     ├─> Reads review feedback
#     ├─> Makes requested changes
#     └─> Commits updates
#
# Skills have pre-approved tools (Read, Write, Edit, Bash) so Claude
# can work autonomously without permission prompts.
#
# ============================================================================
# USAGE
# ============================================================================
#   ./run.sh                              # Process all repos and issues
#   ./run.sh --dry-run                    # Preview only (no Claude invocation)
#   ./run.sh --issue 123                  # Process specific issue #123
#   ./run.sh --repo openonion/oo-api      # Process specific repo only
#   ./run.sh --repo openonion/oo-api --issue 3  # Process issue #3 in oo-api
#
# ============================================================================
# ENVIRONMENT
# ============================================================================
# Configuration via .env file:
#   REPO              - GitHub repo (owner/name)
#   REPO_PATH         - Local clone path
#   MAX_ISSUES        - Max issues per run
#   WORKTREE_BASE     - Where to create worktrees
#   CLAUDE_PATH       - Path to Claude CLI
#   TIMEOUT_SECONDS   - Timeout per issue
#   http_proxy        - HTTP proxy for Claude
#   https_proxy       - HTTPS proxy for Claude

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .env
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# Configuration
REPO="${REPO:-openonion/connectonion}"
REPO_PATH="${REPO_PATH:-$HOME/project/connectonion}"
MAX_ISSUES="${MAX_ISSUES:-10}"
WORKTREE_BASE="${WORKTREE_BASE:-$HOME/worktrees}"
CLAUDE_PATH="${CLAUDE_PATH:-$HOME/.claude/local/claude}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-1800}"

# HTTP Proxy (for Claude CLI) - optional, set in .env if needed
if [[ -n "$http_proxy" ]]; then
    export http_proxy
fi
if [[ -n "$https_proxy" ]]; then
    export https_proxy
fi

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR" "$WORKTREE_BASE"
LOG_FILE="$LOG_DIR/night-runner-$(date +%Y%m%d).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ============================================================================
# Version & Auto-Update
# ============================================================================
VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")

# Check for updates (once per day)
check_for_updates() {
    local last_check_file="$SCRIPT_DIR/.last-update-check"
    local now=$(date +%s)

    # Check if we checked in last 24 hours
    if [[ -f "$last_check_file" ]]; then
        local last_check=$(cat "$last_check_file")
        local diff=$((now - last_check))
        if [[ $diff -lt 86400 ]]; then
            return 0  # Skip check
        fi
    fi

    # Check remote version
    cd "$SCRIPT_DIR"
    git fetch origin main --quiet 2>/dev/null || return 0

    local remote_version=$(git show origin/main:VERSION 2>/dev/null || echo "unknown")

    if [[ "$remote_version" != "$VERSION" && "$remote_version" != "unknown" ]]; then
        log "🔄 New version available: $remote_version (current: $VERSION)"
        log "   Updating Night Runner..."

        # Pull latest
        git pull origin main --quiet 2>/dev/null && \
        log "   ✅ Updated to v$remote_version" || \
        log "   ❌ Update failed, continuing with v$VERSION"
    fi

    # Update last check time
    echo "$now" > "$last_check_file"
}

# Run update check (silent, non-blocking)
check_for_updates 2>/dev/null || true

# Parse arguments
DRY_RUN=false
SPECIFIC_ISSUE=""
SPECIFIC_REPO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --issue) SPECIFIC_ISSUE="$2"; shift 2 ;;
        --repo) SPECIFIC_REPO="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ============================================================================
# Issue Locking - Prevent Concurrent Work on Same Issue
# ============================================================================
LOCK_DIR="$SCRIPT_DIR/.issue-locks"
mkdir -p "$LOCK_DIR"

# Lock an issue before processing
# Returns 0 if lock acquired, 1 if issue is locked by another process
lock_issue() {
    local repo="$1"
    local issue_number="$2"
    local lock_file="$LOCK_DIR/${repo//\//-}-${issue_number}.lock"

    # Check if locked by another process
    if [ -f "$lock_file" ]; then
        local lock_pid=$(cat "$lock_file")
        if ps -p "$lock_pid" > /dev/null 2>&1; then
            return 1  # Locked by running process
        else
            # Stale lock, remove it
            rm -f "$lock_file"
        fi
    fi

    # Acquire lock
    echo $$ > "$lock_file"
    return 0
}

# Unlock an issue after processing
unlock_issue() {
    local repo="$1"
    local issue_number="$2"
    local lock_file="$LOCK_DIR/${repo//\//-}-${issue_number}.lock"

    # Only remove if we own the lock
    if [ -f "$lock_file" ] && [ "$(cat "$lock_file")" = "$$" ]; then
        rm -f "$lock_file"
    fi
}

# Cleanup all locks owned by this process on exit
cleanup_locks() {
    for lock_file in "$LOCK_DIR"/*; do
        [ -f "$lock_file" ] || continue
        if [ "$(cat "$lock_file" 2>/dev/null)" = "$$" ]; then
            rm -f "$lock_file"
        fi
    done
}

trap cleanup_locks EXIT

# ============================================================================
# Helper Functions - State Detection
# ============================================================================
# These functions determine what stage an issue is in by querying GitHub API

# Check if plan comment exists
# Returns: 0 if plan exists, 1 if not
# Detection: Searches for HTML marker <!-- NIGHT_RUNNER_PLAN -->
has_plan() {
    local issue_number="$1"
    gh api "repos/$REPO/issues/$issue_number/comments" 2>/dev/null | \
        grep -q "NIGHT_RUNNER_PLAN"
}

# Get plan comment ID for updating existing plan
# Returns: Comment ID or empty string
# Used by: post_plan() to reply to existing plan instead of creating new one
get_plan_comment_id() {
    local issue_number="$1"
    gh api "repos/$REPO/issues/$issue_number/comments" 2>/dev/null | \
        jq -r '.[] | select(.body | contains("NIGHT_RUNNER_PLAN")) | .id' | head -1
}

# Check if LGTM reply exists (user approval)
# Returns: 0 if approved, 1 if not
# Detection: Exact match - comment body must be exactly "LGTM" (case-insensitive)
# Excludes: Plan comments (with NIGHT_RUNNER_PLAN marker)
has_lgtm() {
    local issue_number="$1"
    gh api "repos/$REPO/issues/$issue_number/comments" 2>/dev/null | \
        jq -r '.[] | select(.body | contains("NIGHT_RUNNER_PLAN") | not) | .body' | \
        grep -Eiq '^\s*lgtm\s*$'
}

# Check if there are comments after the plan (feedback to address)
# Returns: 0 if feedback exists, 1 if not
# Used to detect when user left comments on the plan asking for changes
has_plan_feedback() {
    local issue_number="$1"

    # Get timestamp of the LATEST Night Runner plan (not the first one)
    local latest_plan_time=$(gh api "repos/$REPO/issues/$issue_number/comments" 2>/dev/null | \
        jq -r '[.[] | select(.body | contains("NIGHT_RUNNER_PLAN"))] | last | .created_at')

    if [[ -z "$latest_plan_time" || "$latest_plan_time" == "null" ]]; then
        return 1
    fi

    # Check if there are user comments AFTER the latest plan (excluding LGTM)
    local feedback_count=$(gh api "repos/$REPO/issues/$issue_number/comments" 2>/dev/null | \
        jq --arg plan_time "$latest_plan_time" \
        '[.[] | select(.created_at > $plan_time and (.body | contains("LGTM") | not) and (.body | contains("NIGHT_RUNNER_PLAN") | not))] | length')

    [[ "$feedback_count" -gt 0 ]]
}

# Check if PR exists for issue
# Returns: 0 if PR exists, 1 if not
# Detection: Searches for PR with "fixes #123" in body
has_pr() {
    local issue_number="$1"
    local count=$(gh pr list -R "$REPO" --search "fixes #$issue_number" --json number | jq length)
    [[ "$count" -gt 0 ]]
}

# Get PR number for issue
# Returns: PR number or empty string
# Used by: stage_update_pr() to find which PR to update
get_pr_number() {
    local issue_number="$1"
    gh pr list -R "$REPO" --search "fixes #$issue_number" --json number -q '.[0].number'
}

# Check if PR has new review comments
# Returns: 0 if comments exist, 1 if not
# Note: Currently checks for ANY comments, could be enhanced to check
#       only for comments after last commit timestamp
pr_has_new_comments() {
    local pr_number="$1"
    local count=$(gh api "repos/$REPO/pulls/$pr_number/comments" 2>/dev/null | jq length)
    [[ "$count" -gt 0 ]]
}

# Check if PR is merged
# Returns: 0 if merged, 1 if not
pr_is_merged() {
    local pr_number="$1"
    local merged=$(gh api "repos/$REPO/pulls/$pr_number" 2>/dev/null | jq -r '.merged')
    [[ "$merged" == "true" ]]
}

# Cleanup worktrees for merged PRs
# Scans all worktrees and removes those whose PRs are merged
cleanup_merged_worktrees() {
    log "  Checking for merged PRs to cleanup..."

    # List all night-runner worktrees
    local cleaned=0
    for worktree_path in "$WORKTREE_BASE"/${REPO##*/}-*; do
        if [[ ! -d "$worktree_path" ]]; then
            continue
        fi

        # Extract issue number from worktree name
        local issue_num=$(basename "$worktree_path" | sed "s/${REPO##*/}-//")

        # Check if PR exists and is merged
        local pr_num=$(get_pr_number "$issue_num" 2>/dev/null)
        if [[ -n "$pr_num" ]] && pr_is_merged "$pr_num"; then
            log "  Cleaning up worktree for merged PR #$pr_num (issue #$issue_num)"
            cleanup_worktree "$worktree_path"
            cleaned=$((cleaned + 1))
        fi
    done

    if [[ $cleaned -gt 0 ]]; then
        log "  Cleaned up $cleaned merged PR worktree(s)"
    fi
}

# ============================================================================
# Helper Functions - GitHub Interactions
# ============================================================================

# Post plan comment (or update existing one)
#
# Flow diagram:
#   Check if plan exists
#        │
#        ├─ Yes ─> Reply to existing comment thread
#        │         "🔄 Updated Plan"
#        │         (preserves context & feedback)
#        │
#        └─ No ──> Create new comment
#                  "🤖 Night Runner - Implementation Plan"
#                  (with <!-- NIGHT_RUNNER_PLAN --> marker)
post_plan() {
    local issue_number="$1"
    local plan="$2"
    local issue_title="$3"  # Optional, will fetch if not provided

    # Get issue title if not provided
    if [[ -z "$issue_title" ]]; then
        issue_title=$(gh issue view "$issue_number" -R "$REPO" --json title -q '.title' 2>/dev/null || echo "Issue #$issue_number")
    fi

    # Strip any preamble from Claude's output (e.g., "Perfect! Now I have enough context...")
    # Keep only content starting from first ## heading
    plan=$(echo "$plan" | sed -n '/^##/,$p')

    # Validate plan is not empty
    if [[ -z "$plan" || $(echo "$plan" | tr -d '[:space:]') == "" ]]; then
        log "  ERROR: Plan is empty after stripping preamble"
        log "  This usually means Claude only output preamble text without actual plan content"
        return 1
    fi

    # Build consistent header
    local header="## 🤖 Night Runner - Implementation Plan

**Issue #$issue_number:** $issue_title

---
"

    local footer="

---
*Reply with \`LGTM\` to approve this plan and create a PR.*

🤖 *Automated by [Night Runner](https://github.com/openonion/night-runner) - OpenOnion's 24/7 code worker*

<!-- NIGHT_RUNNER_PLAN -->"

    local body="${header}${plan}${footer}"

    # Check if plan comment already exists
    local existing_comment_id=$(get_plan_comment_id "$issue_number")

    if [[ -n "$existing_comment_id" ]]; then
        # Update existing plan (post as new comment, not reply)
        log "  Updating existing plan (comment #$existing_comment_id)..."

        # Use same format for updates
        gh issue comment "$issue_number" -R "$REPO" --body "$body"
    else
        # Create new plan comment
        gh issue comment "$issue_number" -R "$REPO" --body "$body"
    fi
}

# Run Claude with a skill
#
# Flow:
#   run_claude "$worktree_path" "/night-runner-implement 123"
#        │
#        ├─> cd into target directory
#        ├─> export GH_REPO (so gh commands work without -R)
#        ├─> export http_proxy, https_proxy (from .env)
#        │
#        ├─> Run: claude --dangerously-skip-permissions -p "/skill-name args"
#        │    │
#        │    ├─> Claude loads skill from ~/.claude/skills/skill-name/SKILL.md
#        │    ├─> Skills have allowed-tools (pre-approved permissions)
#        │    ├─> Claude executes skill instructions
#        │    └─> Returns output
#        │
#        ├─> Timeout after TIMEOUT_SECONDS (default 30min)
#        │
#        └─> Capture stdout/stderr to temp file
#             ├─> Success: Return output
#             └─> Failure: Log to file, return error
#
# Args:
#   $1 - Working directory (where to run Claude)
#   $2 - Skill command (e.g., "/night-runner-plan 123")
#
# Returns:
#   0 - Success (output on stdout)
#   1 - Failure (logged to LOG_FILE)
run_claude() {
    local cwd="$1"
    local skill_cmd="$2"
    local output_file="$LOG_DIR/.claude-output-$$"

    cd "$cwd"
    # Set GH_REPO so skills can use gh without -R flag
    export GH_REPO="$REPO"

    if timeout "$TIMEOUT_SECONDS" "$CLAUDE_PATH" --dangerously-skip-permissions -p "$skill_cmd" > "$output_file" 2>&1; then
        cat "$output_file"
        rm -f "$output_file"
        return 0
    else
        cat "$output_file" >> "$LOG_FILE"
        rm -f "$output_file"
        return 1
    fi
}

# Setup worktree (continues from existing branch if exists)
#
# Git worktree creates an isolated working directory for each issue:
#
#   Main repo (stays on main, untouched):
#   ~/project/connectonion/
#        └── .git/  ← Shared git database
#
#   Worktree (isolated workspace):
#   ~/worktrees/connectonion-123/
#        └── on branch: night-runner/123
#
# Benefits:
#   - No branch switching in main repo
#   - Parallel work on multiple issues
#   - Clean isolation
#   - Shared .git saves disk space
#
# Progressive work:
#   First run:  Creates new branch from origin/main
#   Next runs:  Reuses existing branch (continues where left off)
#   This allows:
#     - Long tasks to split across runs
#     - Failures to retry without losing progress
#     - PR updates to build on previous work
#
# Args:
#   $1 - Issue number
#
# Returns:
#   Prints worktree path on success
#   Returns 1 on failure
setup_worktree() {
    local issue_number="$1"
    local branch="night-runner/$issue_number"
    local worktree="$WORKTREE_BASE/${REPO##*/}-$issue_number"

    # Cleanup worktree dir if exists (git worktree can't reuse same path)
    if [[ -d "$worktree" ]]; then
        git -C "$REPO_PATH" worktree remove "$worktree" --force 2>/dev/null || true
    fi

    cd "$REPO_PATH"
    git fetch origin >/dev/null 2>&1

    # Check if branch exists (remote or local)
    if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
        # Branch exists on remote - use it
        git worktree add "$worktree" "$branch" >/dev/null 2>&1 || \
            git worktree add "$worktree" -b "$branch" "origin/$branch" >/dev/null 2>&1 || return 1
        log "  Continuing from existing branch" >&2
    elif git show-ref --verify --quiet "refs/heads/$branch"; then
        # Branch exists locally but not on remote - use local branch
        git worktree add "$worktree" "$branch" >/dev/null 2>&1 || return 1
        log "  Continuing from local branch" >&2
    else
        # No branch exists - create new one from main
        git worktree add "$worktree" -b "$branch" origin/main >/dev/null 2>&1 || return 1
        log "  Created new branch" >&2
    fi

    echo "$worktree"
}

# Cleanup worktree after use
# Note: Branch is kept on remote for next run, only local worktree removed
cleanup_worktree() {
    local worktree="$1"
    if [[ -d "$worktree" ]]; then
        git -C "$REPO_PATH" worktree remove "$worktree" --force 2>/dev/null || true
    fi
}

# ============================================================================
# Stage Handlers - The 3 Stages of Issue Resolution
# ============================================================================
#
# Stage 1: Plan       (NO_PLAN → PLAN_POSTED)
# Stage 2: Implement  (LGTM → PR_CREATED)
# Stage 3: Update PR  (HAS_REVIEW_COMMENTS → PR_UPDATED)
#

# Stage 1: Create implementation plan
#
# Flow:
#   issue #123 (no plan)
#        │
#        ├─> run_claude("/night-runner-plan 123")
#        │    │
#        │    ├─> Claude: gh issue view 123
#        │    ├─> Claude: Read related code (Glob/Grep/Read)
#        │    ├─> Claude: Generate plan with diagrams:
#        │    │           - Workflow diagram
#        │    │           - File structure
#        │    │           - Architecture
#        │    │           - Data flow
#        │    │           - Implementation steps
#        │    └─> Return: Markdown plan
#        │
#        └─> post_plan() → gh issue comment
#             └─> "Reply with LGTM to approve"
#
# On success: Issue moves to WAITING_APPROVAL state
stage_plan() {
    local issue_number="$1"
    local issue_title="$2"

    # React to issue to show Night Runner is working on it (👀)
    gh api -X POST "repos/$REPO/issues/$issue_number/reactions" -f content="eyes" 2>/dev/null || true

    log "  Creating plan..."

    # Pass issue number, title, and URL to help Claude focus on the correct issue
    local issue_url="https://github.com/$REPO/issues/$issue_number"
    local plan=$(run_claude "$REPO_PATH" "/night-runner-plan $issue_number" <<EOF
Create an implementation plan for this specific issue:

Issue #$issue_number: "$issue_title"
URL: $issue_url

Use the /night-runner-plan skill to create the plan.
Focus ONLY on this specific issue, not any other issues.
EOF
)

    if [[ -z "$plan" ]]; then
        log "  Failed to generate plan"
        return 1
    fi

    post_plan "$issue_number" "$plan" "$issue_title"
    log "  Plan posted"
}

# Stage 2: Implement and create PR
#
# Flow:
#   User replied "LGTM"
#        │
#        ├─> setup_worktree(123)
#        │    └─> Creates ~/worktrees/connectonion-123/
#        │        on branch night-runner/123
#        │
#        ├─> run_claude("/night-runner-implement 123")
#        │    │
#        │    ├─> Claude: gh issue view 123
#        │    ├─> Claude: Read codebase
#        │    ├─> Claude: Edit files
#        │    ├─> Claude: git commit (frequent commits!)
#        │    ├─> Claude: Edit more files
#        │    ├─> Claude: git commit
#        │    └─> Claude: Final commit "fixes #123"
#        │
#        ├─> Catch any uncommitted work
#        │    └─> git add -A && git commit -m "wip"
#        │
#        ├─> Verify commits exist
#        │    └─> git log origin/main..HEAD
#        │
#        ├─> git push -u origin night-runner/123
#        │
#        ├─> gh pr create --draft
#        │    └─> Body includes "Fixes #123" (auto-links)
#        │
#        └─> cleanup_worktree()
#             └─> Removes local worktree, keeps remote branch
#
# On success: Issue moves to PR_CREATED state
stage_implement() {
    local issue_number="$1"
    local title="$2"

    log "  Implementing..."

    local worktree=$(setup_worktree "$issue_number")
    if [[ -z "$worktree" ]]; then
        log "  Failed to setup worktree"
        return 1
    fi

    # Create/update progress tracking file
    cat > "$worktree/NIGHT_RUNNER_PROGRESS.md" <<EOF
# Night Runner Progress for Issue #$issue_number

Last run: $(date '+%Y-%m-%d %H:%M:%S')
Status: In Progress

## What to do next
- Read this file to see what's already done
- Continue implementing remaining tasks
- Update this file with completed tasks
- Commit frequently

## Completed Tasks
(Claude will update this section)

EOF

    run_claude "$worktree" "/night-runner-implement $issue_number" > /dev/null
    local claude_exit_code=$?

    cd "$worktree"

    # Update progress file with timestamp
    if [[ -f "NIGHT_RUNNER_PROGRESS.md" ]]; then
        echo "" >> NIGHT_RUNNER_PROGRESS.md
        echo "Last attempt: $(date '+%Y-%m-%d %H:%M:%S')" >> NIGHT_RUNNER_PROGRESS.md
        echo "Exit code: $claude_exit_code" >> NIGHT_RUNNER_PROGRESS.md
    fi

    # Commit any remaining uncommitted changes (in case Claude didn't commit everything)
    if ! git diff --quiet || ! git diff --staged --quiet; then
        git add -A
        git commit -m "wip: continue work on #$issue_number [night-runner]" || true
    fi

    # Check if any commits were made (compare to origin/main)
    # If no commits, Claude likely failed or had nothing to change
    local commits=$(git log origin/main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$commits" == "0" ]]; then
        log "  No commits made"
        cleanup_worktree "$worktree"
        return 1
    fi

    log "  Made $commits commit(s)"

    # ALWAYS push commits (even if incomplete) so next run can continue
    local branch="night-runner/$issue_number"
    git push -u origin "$branch" 2>&1 | head -5 || {
        log "  Warning: Push failed, but continuing..."
    }

    # Create PR
    gh pr create \
        -R "$REPO" \
        --title "fix: $title" \
        --body "## Summary
Fixes #$issue_number

## Changes
$(git log origin/main..$branch --oneline)

---
🤖 Generated with [Claude Code](https://claude.ai/code) via Night Runner

<!-- NIGHT_RUNNER_PR -->" \
        --draft

    # Keep worktree (don't cleanup) - will be cleaned up after PR is merged
    log "  PR created (worktree preserved for updates)"
    log "  Worktree: $worktree"
}

# Stage 3: Update PR based on review comments
#
# Flow:
#   PR has review comments
#        │
#        ├─> setup_worktree(123)
#        │    └─> Reuses existing branch night-runner/123
#        │        (continues from previous work)
#        │
#        ├─> run_claude("/night-runner-update-pr 42")
#        │    │
#        │    ├─> Claude: gh pr view 42 --json reviews,comments
#        │    ├─> Claude: Read review feedback
#        │    ├─> Claude: Make requested changes
#        │    ├─> Claude: git commit
#        │    └─> Claude: Address more feedback
#        │
#        ├─> Catch any uncommitted work
#        │    └─> git commit -m "address review feedback"
#        │
#        ├─> git push (updates existing PR automatically)
#        │
#        └─> cleanup_worktree()
#
# On success: PR updated, ready for re-review
stage_update_pr() {
    local issue_number="$1"
    local pr_number="$2"

    log "  Updating PR #$pr_number..."

    local worktree=$(setup_worktree "$issue_number")
    if [[ -z "$worktree" ]]; then
        log "  Failed to setup worktree"
        return 1
    fi

    run_claude "$worktree" "/night-runner-update-pr $pr_number" > /dev/null

    cd "$worktree"

    # Commit any remaining uncommitted changes
    if ! git diff --quiet || ! git diff --staged --quiet; then
        git add -A
        git commit -m "address review feedback" || true
    fi

    # Push all commits (automatically updates the PR)
    git push || true

    # Keep worktree (don't cleanup) - will be cleaned up after PR is merged
    log "  PR updated (worktree preserved for further updates)"
    log "  Worktree: $worktree"
}

# ============================================================================
# Process Repository - Main Logic for a Single Repo
# ============================================================================
#
# For each issue, determines current state and takes appropriate action:
#
#   Issue state detection (priority order):
#        │
#        ├─ has_pr() ? ───────────────┐
#        │   Yes                      │ No
#        │    ├─ pr_has_new_comments()?   │
#        │    │   Yes: stage_update_pr    │
#        │    │   No:  Skip (no action)   │
#        │                            │
#        ├─ has_lgtm() ? ─────────────┤
#        │   Yes: stage_implement     │ No
#        │                            │
#        ├─ has_plan() ? ─────────────┤
#        │   Yes: Skip (waiting LGTM) │ No
#        │                            │
#        └─ No plan: stage_plan() ────┘
#
# This creates a state machine where each issue progresses through stages.

process_repo() {
log "Repo: $REPO"

# Cleanup worktrees for merged PRs first
cleanup_merged_worktrees

# Fetch issues from GitHub
# Either specific issue or all open issues (up to MAX_ISSUES)
if [[ -n "$SPECIFIC_ISSUE" ]]; then
    ISSUES=$(gh issue view "$SPECIFIC_ISSUE" -R "$REPO" --json number,title,body,labels 2>/dev/null | jq -s '.')
else
    # Get ALL open issues (no limit), then filter out those with "manual" label
    ALL_ISSUES=$(gh issue list -R "$REPO" --state open --limit 100 --json number,title,body,labels)
    ISSUES=$(echo "$ALL_ISSUES" | jq '[.[] | select(.labels | map(.name) | contains(["manual"]) | not)]')

    # Apply MAX_ISSUES limit after filtering
    if [[ -n "$MAX_ISSUES" && "$MAX_ISSUES" -gt 0 ]]; then
        ISSUES=$(echo "$ISSUES" | jq ".[:$MAX_ISSUES]")
    fi
fi

COUNT=$(echo "$ISSUES" | jq length)
log "Found $COUNT open issues"

if [[ "$COUNT" == "0" ]]; then
    log "No issues to process"
    exit 0
fi

# Process each issue
echo "$ISSUES" | jq -c '.[]' | while read -r issue; do
    NUMBER=$(echo "$issue" | jq -r '.number')
    TITLE=$(echo "$issue" | jq -r '.title')

    log "Issue #$NUMBER: $TITLE"

    # Try to acquire lock on this issue
    if ! lock_issue "$REPO" "$NUMBER"; then
        log "  Locked by another process, skipping"
        continue
    fi

    if $DRY_RUN; then
        unlock_issue "$REPO" "$NUMBER"
        if has_pr "$NUMBER"; then
            log "  [DRY RUN] Has PR - would check for updates"
        elif has_lgtm "$NUMBER"; then
            log "  [DRY RUN] Has LGTM - would create PR"
        elif has_plan "$NUMBER"; then
            if has_plan_feedback "$NUMBER"; then
                log "  [DRY RUN] Has plan with feedback - would update plan"
            else
                log "  [DRY RUN] Has plan - waiting for LGTM"
            fi
        else
            log "  [DRY RUN] No plan - would create plan"
        fi
        continue
    fi

    # Check state and act (priority order matters!)
    # 1. PR exists → Check for review comments to address
    # 2. LGTM received → Implement and create PR
    # 3. Plan has feedback → Update plan addressing comments
    # 4. Plan exists → Wait for user approval
    # 5. No plan → Create one
    if has_pr "$NUMBER"; then
        PR_NUM=$(get_pr_number "$NUMBER")
        if pr_has_new_comments "$PR_NUM"; then
            stage_update_pr "$NUMBER" "$PR_NUM"
        else
            log "  PR exists, no new comments"
        fi
    elif has_lgtm "$NUMBER"; then
        stage_implement "$NUMBER" "$TITLE"
    elif has_plan "$NUMBER"; then
        if has_plan_feedback "$NUMBER"; then
            log "  Plan has feedback, updating plan..."
            stage_plan "$NUMBER" "$TITLE"
        else
            log "  Plan exists, waiting for LGTM"
        fi
    else
        stage_plan "$NUMBER" "$TITLE"
    fi

    # Release lock after processing
    unlock_issue "$REPO" "$NUMBER"
done
}

# ============================================================================
# Main Entry Point - Multi-Repo Support
# ============================================================================

log "===== Night Runner v$VERSION Start ====="

# Handle --repo flag (process specific repo only)
if [[ -n "$SPECIFIC_REPO" ]]; then
    # Find repo in REPO_LIST
    FOUND=false
    while IFS='|' read -r repo path; do
        [[ -z "$repo" || "$repo" =~ ^[[:space:]]*# ]] && continue
        if [[ "$repo" == "$SPECIFIC_REPO" ]]; then
            REPO="$repo"
            REPO_PATH=$(eval echo "$path")
            FOUND=true
            break
        fi
    done <<< "$REPO_LIST"

    if ! $FOUND; then
        log "ERROR: Repo '$SPECIFIC_REPO' not found in REPO_LIST"
        exit 1
    fi

    log "Processing specific repo: $REPO"
    process_repo
    log ""
    log "===== Night Runner Done ====="
    exit 0
fi

# Support multiple repos from REPO_LIST
if [[ -n "$REPO_LIST" ]]; then
    # Parse REPO_LIST (format: "repo|path" one per line)
    REPO_COUNT=0
    while IFS='|' read -r repo path; do
        # Skip empty lines and comments
        [[ -z "$repo" || "$repo" =~ ^[[:space:]]*# ]] && continue

        # Expand variables like $HOME
        path=$(eval echo "$path")

        REPO_COUNT=$((REPO_COUNT + 1))
    done <<< "$REPO_LIST"

    log "Processing $REPO_COUNT repositories"

    CURRENT=0
    while IFS='|' read -r repo path; do
        # Skip empty lines and comments
        [[ -z "$repo" || "$repo" =~ ^[[:space:]]*# ]] && continue

        CURRENT=$((CURRENT + 1))

        # Expand variables like $HOME
        path=$(eval echo "$path")

        REPO="$repo"
        REPO_PATH="$path"

        log ""
        log "===== Repository $CURRENT/$REPO_COUNT ====="
        process_repo
    done <<< "$REPO_LIST"
else
    # Single repo (backward compatible)
    process_repo
fi

log ""
log "===== Night Runner Done ====="
