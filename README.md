<div align="center">

<img src="https://raw.githubusercontent.com/wu-changxing/openonion-assets/master/imgs/Onion.png" width="140" alt="OpenOnion Logo">

# Night Runner

### Auto-run Claude Code on GitHub issues overnight. Wake up to PRs.

🧅 **OpenOnion = Open Source** • Built with [**ConnectOnion**](https://github.com/openonion/connectonion), the best and simplest AI agent framework

[![GitHub](https://img.shields.io/badge/GitHub-openonion%2Fnight--runner-blue?logo=github)](https://github.com/openonion/night-runner)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## 🚀 Installation (Copy & Paste)

**Easiest way - Just copy this into Claude Code:**

```
Install Night Runner for me: https://github.com/openonion/night-runner

1. Clone to ~/night-runner
2. Link skills to ~/.claude/skills/
3. Check gh CLI is installed and authenticated
4. Ask me configuration questions (repo, paths, label)
5. Create .env file
6. Offer to create a test issue

Guide me through the setup interactively!
```

**Or even simpler - just paste the URL:**

```
https://github.com/openonion/night-runner

Install and set this up for me. Ask questions to configure it.
```

Claude Code will handle everything automatically. Setup takes ~5 minutes.

---

### Manual Setup

If you prefer manual setup:

#### Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- A GitHub repository you want to automate

#### Installation

1. **Clone this repository**
   ```bash
   git clone https://github.com/openonion/night-runner.git
   cd night-runner
   ```

2. **Link skills to Claude Code**

   Skills must be in `~/.claude/skills/` to be accessible:
   ```bash
   # Create skills directory if it doesn't exist
   mkdir -p ~/.claude/skills

   # Create symlinks to make skills available globally
   ln -s "$(pwd)/.claude/skills/night-runner-plan" ~/.claude/skills/
   ln -s "$(pwd)/.claude/skills/night-runner-implement" ~/.claude/skills/
   ln -s "$(pwd)/.claude/skills/night-runner-update-pr" ~/.claude/skills/
   ```

3. **Configure your repository**

   Copy the example config and customize:
   ```bash
   cp .env.example .env
   ```

   Edit `.env` with your settings:
   ```bash
   # GitHub repo to process (owner/repo)
   REPO="yourusername/yourrepo"

   # Path to local clone of the repo
   REPO_PATH="$HOME/path/to/your/repo"

   # Label to filter issues (issues must have this label)
   LABEL="auto"

   # Max issues to process per run
   MAX_ISSUES=5

   # Worktree base directory (isolated workspaces per issue)
   WORKTREE_BASE="$HOME/worktrees"
   ```

4. **Test on a single issue**

   First, create a test issue in your repo and add the label (e.g., "auto"):
   ```bash
   gh issue create --repo yourusername/yourrepo \
     --title "Test: Add hello world function" \
     --label "auto" \
     --body "Create a simple hello world function in src/utils.py"
   ```

   Then run Night Runner on that issue:
   ```bash
   ./run.sh --issue 123  # Replace 123 with your issue number
   ```

   This will:
   - Create a plan as a comment on the issue
   - Wait for you to review
   - Reply `LGTM` to the plan comment to approve
   - Run again: `./run.sh --issue 123`
   - Night Runner will implement and create a PR

### Full Automation (Optional)

Once you've tested manually, set up automatic scheduling:

**macOS (launchd):**
```bash
./manage.sh install   # Install and start
./manage.sh status    # Check if running
./manage.sh logs      # View logs
```

**Linux (cron):**
```bash
# Run every hour
0 * * * * cd /path/to/night-runner && ./run.sh >> logs/cron.log 2>&1
```

---

## Workflow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Open Issue  │────▶│  Plan        │────▶│  LGTM        │────▶│  PR Created  │
│              │     │  Comment     │     │  Reply       │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
       │                    │                    │                     │
       │                    │                    │                     │
       ▼                    ▼                    ▼                     ▼
   Night Runner        You review          Night Runner          You review
   creates plan        the plan            implements            the PR
                                           & creates PR
```

**Stage 1: Plan**
- Night Runner scans open issues
- Creates implementation plan as comment
- Waits for your approval

**Stage 2: Approval**
- You review the plan
- Reply `LGTM` to approve
- (Or provide feedback for revision)

**Stage 3: Implementation**
- Night Runner implements the plan
- Creates draft PR
- Links to original issue

**Stage 4: Review**
- You review the PR
- Add comments if changes needed
- Night Runner updates PR next run
- Merge when ready

## Example Walkthrough

Let's walk through a complete example:

**1. Create an issue with the automation label:**
```bash
gh issue create --repo myorg/myrepo \
  --title "Add user authentication" \
  --label "auto" \
  --body "Implement basic username/password authentication"
```
→ Created issue #42

**2. Run Night Runner to create a plan:**
```bash
./run.sh --issue 42
```
→ Night Runner posts a plan comment with:
- Implementation approach
- File changes needed
- Architecture diagrams
- "Reply with `LGTM` to approve"

**3. Review and approve the plan:**
Go to the issue, read the plan, and reply:
```
LGTM
```

**4. Run Night Runner to implement:**
```bash
./run.sh --issue 42
```
→ Night Runner:
- Creates git worktree at `~/worktrees/myrepo-42`
- Makes progressive commits
- Creates PR #43 with link to issue #42
- Preserves worktree for updates

**5. Review the PR and request changes:**
Add review comments on specific lines:
```
Please add error handling for invalid passwords
```

**6. Run Night Runner to update PR:**
```bash
./run.sh --issue 42
```
→ Night Runner:
- Detects review comments
- Continues in existing worktree
- Makes new commits addressing feedback
- Pushes to same PR #43

**7. Merge when satisfied:**
Merge PR #43 manually. Next run will auto-cleanup the worktree.

---

## Commands

```bash
./manage.sh install      # Install scheduled job (8 PM - 10 AM hourly)
./manage.sh uninstall    # Remove scheduled job
./manage.sh status       # Check status
./manage.sh logs         # View logs
./manage.sh run          # Dry run (preview)
./manage.sh run-one      # Process one issue
./manage.sh run-issue N  # Process specific issue #N
```

## How It Detects State

| State | Detection |
|-------|-----------|
| Needs plan | No `<!-- NIGHT_RUNNER_PLAN -->` comment |
| Waiting approval | Has plan, no `LGTM` reply |
| Ready to implement | Has `LGTM` reply |
| PR exists | `gh pr list --search "fixes #N"` |
| PR needs update | PR has review comments |

---

## Project Structure

```
night-runner/
├── .env.example          # Config template
├── .env                  # Your config (gitignored)
├── .gitignore
├── README.md
├── run.sh                # Main script
├── manage.sh             # Management commands
├── com.openonion.night-runner.plist.template
├── .claude/skills/       # Claude Code skills
│   ├── night-runner-plan/SKILL.md
│   ├── night-runner-implement/SKILL.md
│   └── night-runner-update-pr/SKILL.md
└── logs/                 # Logs (gitignored)
```

## Skills

Night Runner uses Claude Code skills with pre-approved tools:

| Skill | Purpose | Allowed Tools |
|-------|---------|---------------|
| `/night-runner-plan` | Create implementation plan | Read, Glob, Grep, Bash(gh *) |
| `/night-runner-implement` | Implement and commit | Read, Write, Edit, Glob, Grep, Bash(git/gh/npm/...) |
| `/night-runner-update-pr` | Address review feedback | Same as implement |

You can also run these skills manually:
```bash
claude -p "/night-runner-plan 123"
```

## License

MIT

---

<div align="center">

**Built by [OpenOnion](https://github.com/openonion) 🧅**

*Open Source • Open Community*

Powered by [**ConnectOnion**](https://github.com/openonion/connectonion) - The best and simplest AI agent framework

[Documentation](https://docs.connectonion.com) • [Discord](https://discord.gg/4xfD9k8AUF)

</div>
