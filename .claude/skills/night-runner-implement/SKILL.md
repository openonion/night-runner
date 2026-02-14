---
name: night-runner-implement
description: Implement fix for a GitHub issue and create commits
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(gh *), Bash(npm *), Bash(pnpm *), Bash(yarn *), Bash(python *), Bash(pytest *), Bash(cargo *), Bash(go *)
argument-hint: [issue-number]
---

# Implement Fix

Fix GitHub issue #$ARGUMENTS.

## Step 1: Check for Previous Work

**IMPORTANT**: This might be a continuation of previous work. Check if progress file exists:

```bash
cat NIGHT_RUNNER_PROGRESS.md 2>/dev/null || echo "No previous progress"
```

If the file exists:
- Read what's already been done
- Continue from where it left off
- Update the "Completed Tasks" section as you make progress
- Don't redo completed work

## Step 2: Get Issue Details

Get issue details:
```bash
gh issue view $ARGUMENTS --json title,body
```

## IMPORTANT - Commit Frequently & Track Progress

- Commit after EACH meaningful change
- Don't batch everything into one commit
- Use descriptive commit messages
- Progress is better than perfection
- If you can't finish everything, commit what you have
- **Update NIGHT_RUNNER_PROGRESS.md after each major step**

## Instructions

1. Check NIGHT_RUNNER_PROGRESS.md for previous work
2. Explore the codebase to understand the context
3. Implement the fix step by step
4. After EACH step:
   - Commit the changes: `git commit -m "descriptive message"`
   - Update NIGHT_RUNNER_PROGRESS.md with what you completed
5. Final commit should reference: `fixes #$ARGUMENTS`

## Progress Tracking

Update NIGHT_RUNNER_PROGRESS.md like this:
```markdown
## Completed Tasks
- [x] Read codebase and understood structure
- [x] Added base64 image handling in Python SDK
- [x] Updated WebSocket message format
- [ ] Add TypeScript SDK support (IN PROGRESS)
- [ ] Add oo-chat UI display
- [ ] Add tests
```

This helps the next run know exactly where you left off!

## Guidelines

- Keep changes minimal and focused
- Follow existing code patterns
- Don't refactor unrelated code
- Add tests if the project has tests
