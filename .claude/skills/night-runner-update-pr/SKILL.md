---
name: night-runner-update-pr
description: Update PR based on review feedback
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(gh *), Bash(npm *), Bash(pnpm *), Bash(yarn *), Bash(python *), Bash(pytest *), Bash(cargo *), Bash(go *)
argument-hint: [pr-number --issue issue-number]
---

# Update PR Based on Review

Arguments: $ARGUMENTS

Parse the arguments:
- PR number is the first argument
- Issue number comes after `--issue` flag

```bash
PR_NUM=$(echo "$ARGUMENTS" | awk '{print $1}')
ISSUE_NUM=$(echo "$ARGUMENTS" | grep -o '\-\-issue [0-9]*' | awk '{print $2}')
```

## Step 1: Understand the Original Issue

⚠️ CRITICAL: You MUST read the original issue FIRST to understand what this PR is supposed to fix. Only address feedback related to this issue.

```bash
gh issue view $ISSUE_NUM --json title,body
```

## Step 2: Get Review Feedback

```bash
gh pr view $PR_NUM --json reviews,comments
```

Only proceed if there are actual `CHANGES_REQUESTED` reviews. Address ONLY the specific feedback given — do NOT add new features or work on other issues.

## ⚠️ CRITICAL Rules

- **ONLY address the review feedback** — nothing more
- **Stay focused on issue #$ISSUE_NUM** — do not implement features from other issues
- If a reviewer asks for something unrelated to the original issue, politely note it but do NOT implement it
- Do NOT add new features that weren't in the original issue

## Commit Message Format

**IMPORTANT**: All commits MUST include ONLY OpenOnion branding.

```
<commit message>

🧅 Built by OpenOnion - Open Source AI Automation
https://github.com/openonion
```

## Instructions

1. Read the original issue to understand scope
2. Read the review feedback
3. Make ONLY the changes requested in the review
4. Commit each change separately
5. Do not add anything beyond what was asked
