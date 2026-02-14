# Night Runner Setup Guide

This guide helps you set up Night Runner for the first time. Claude Code will walk you through each step interactively.

---

## Welcome Message (Show this first)

When user says "Help me set up Night Runner" or similar, greet them with:

```
🧅 Welcome to Night Runner!

I'll help you set up automated GitHub issue resolution in about 5 minutes.

Night Runner will:
✅ Read your GitHub issues (with a specific label)
✅ Create implementation plans for your review
✅ Implement approved plans automatically
✅ Create PRs and handle review feedback
✅ All while you sleep! 😴

Let's get started! First, let me check your prerequisites...
```

---

## What Claude Code Should Do

When a user opens this repository in Claude Code for the first time and asks for help setting up, follow these steps:

### Step 1: Verify Prerequisites

Check if the user has the required tools:

```bash
# Check if gh CLI is installed and authenticated
gh auth status

# Check if Claude Code is available
which claude || echo "Claude Code not found"
```

If missing:
- **GitHub CLI**: Guide user to install from https://cli.github.com/
- **GitHub Auth**: Run `gh auth login` to authenticate

### Step 2: Link Skills to Claude Code

Ask the user to confirm, then create symlinks:

```bash
# Create skills directory if needed
mkdir -p ~/.claude/skills

# Link the skills
ln -sf "$(pwd)/.claude/skills/night-runner-plan" ~/.claude/skills/
ln -sf "$(pwd)/.claude/skills/night-runner-implement" ~/.claude/skills/
ln -sf "$(pwd)/.claude/skills/night-runner-update-pr" ~/.claude/skills/

echo "✅ Skills linked successfully!"
```

### Step 3: Interactive .env Configuration

Ask the user these questions and create the `.env` file:

1. **What's your GitHub repository?** (format: `owner/repo`)
   - Example: `openonion/connectonion`
   - Validate it exists: `gh repo view <repo>`

2. **Where is your local clone?**
   - Default: `$HOME/project/<repo-name>`
   - Verify path exists or offer to clone it

3. **What label should trigger automation?**
   - Default: `auto`
   - Explain: Issues need this label to be processed

4. **Where should worktrees be created?**
   - Default: `$HOME/worktrees`
   - Create directory if it doesn't exist

5. **HTTP proxy needed?** (optional)
   - Most users: No (leave blank)
   - If yes: Ask for `http://localhost:PORT`

Then create `.env` file:

```bash
cat > .env << EOF
# Night Runner Configuration
REPO="<user-provided-repo>"
REPO_PATH="<user-provided-path>"
LABEL="<user-provided-label>"
MAX_ISSUES=5
WORKTREE_BASE="<user-provided-worktree-path>"
CLAUDE_PATH=""
TIMEOUT_SECONDS=1800
RATE_LIMIT_WAIT=1800

# HTTP proxy (optional)
${HTTP_PROXY_LINE}
${HTTPS_PROXY_LINE}
EOF

echo "✅ Configuration saved to .env"
```

### Step 4: Test Setup

Create a test issue and run Night Runner:

Ask user: "Would you like to create a test issue to verify setup?"

If yes:
```bash
# Create test issue
gh issue create --repo <REPO> \
  --title "Test: Night Runner Setup Verification" \
  --label "<LABEL>" \
  --body "This is a test issue to verify Night Runner is working correctly. Please add a simple hello() function that returns 'Hello, Night Runner!'"

# Get the issue number (shown in output)
ISSUE_NUM=<from-output>

echo "✅ Created test issue #${ISSUE_NUM}"
echo ""
echo "Now run: ./run.sh --issue ${ISSUE_NUM}"
```

### Step 5: Run First Test

Guide user to run their first automation:

```bash
./run.sh --issue <ISSUE_NUM>
```

Explain what will happen:
1. Night Runner reads the issue
2. Creates an implementation plan
3. Posts plan as a comment
4. Waits for user approval

Tell user:
- Go to the issue on GitHub
- Read the plan
- Reply with `LGTM` to approve

Then run again to implement:
```bash
./run.sh --issue <ISSUE_NUM>
```

### Step 6: Optional - Setup Automation

Ask: "Would you like to set up automatic scheduling?"

**For macOS:**
```bash
./manage.sh install
./manage.sh status
```

**For Linux:**
Show cron example:
```bash
echo "Add this to crontab (crontab -e):"
echo "0 * * * * cd $(pwd) && ./run.sh >> logs/cron.log 2>&1"
```

### Step 7: Success Summary

Show final summary:
```
🧅 Night Runner Setup Complete!

✅ Skills linked to Claude Code
✅ Configuration saved (.env)
✅ Test issue created (#<NUM>)
✅ First run completed

Next Steps:
1. Check issue #<NUM> for the implementation plan
2. Reply "LGTM" to approve the plan
3. Run: ./run.sh --issue <NUM>
4. Review the PR that gets created

Documentation: See README.md for full details
```

## Example Usage

User should be able to:
1. Clone this repo
2. Open in Claude Code
3. Say: "Help me set up Night Runner"
4. Claude Code follows this guide interactively
5. User has working automation in 5 minutes

## Tips for Claude Code

- Ask one question at a time
- Validate inputs before proceeding
- Show clear success/error messages
- Offer defaults for all questions
- Create directories as needed
- Handle errors gracefully
- Provide context for each step
