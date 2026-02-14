---
name: night-runner-update-pr
description: Update PR based on review feedback
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(gh *), Bash(npm *), Bash(pnpm *), Bash(yarn *), Bash(python *), Bash(pytest *), Bash(cargo *), Bash(go *)
argument-hint: [pr-number]
---

# Update PR Based on Review

Update PR #$ARGUMENTS based on review feedback.

## Get Review Comments

First, fetch the review comments:
```bash
gh pr view $ARGUMENTS --json reviews,comments
```

## IMPORTANT - Commit Frequently

- Commit after EACH change you make
- Don't batch all changes into one commit
- If you can't finish, commit what you have

## Instructions

1. Read and understand the feedback
2. Make the requested changes
3. Commit each change separately
4. If feedback is unclear, make your best judgment

## Guidelines

- Address each comment specifically
- Don't make unrelated changes
- Keep commits focused
