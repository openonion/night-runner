<div align="center">

<img src="https://raw.githubusercontent.com/wu-changxing/openonion-assets/master/imgs/Onion.png" width="120" alt="OpenOnion Logo">

# Night Runner

```
   ____                   ____        _
  / __ \____  ___  ____  / __ \____  (_)___  ____
 / / / / __ \/ _ \/ __ \/ / / / __ \/ / __ \/ __ \
/ /_/ / /_/ /  __/ / / / /_/ / / / / / /_/ / / / /
\____/ .___/\___/_/ /_/\____/_/ /_/_/\____/_/ /_/
    /_/
```

**Auto-run Claude Code on GitHub issues overnight. Wake up to PRs.**

> 🧅 **OpenOnion = Open Source** - Built with [ConnectOnion](https://github.com/openonion/connectonion), the best and simplest AI agent framework.

</div>

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

## Setup

```bash
# 1. Clone
git clone https://github.com/openonion/night-runner
cd night-runner

# 2. Configure
cp .env.example .env
# Edit .env with your repo path

# 3. Test
./manage.sh run        # Dry run
./manage.sh run-one    # Process one issue

# 4. Install (runs hourly 8 PM - 10 AM)
./manage.sh install
```

## Configuration

Edit `.env`:

```bash
REPO="your-org/your-repo"
REPO_PATH="$HOME/path/to/local/clone"
MAX_ISSUES=10
```

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

## Example

**1. You create an issue:**
```
Title: Add dark mode support
Body: Users should be able to toggle dark mode...
```

**2. Night Runner comments (overnight):**
```markdown
## 🤖 Night Runner - Implementation Plan

### Summary
Add dark mode toggle to the application.

### Files to change
- src/styles/theme.css
- src/components/ThemeToggle.tsx
- src/hooks/useTheme.ts

### Approach
1. Create CSS variables for colors
2. Add ThemeToggle component
3. Persist preference in localStorage

---
*Reply with `LGTM` to approve this plan and create a PR.*
```

**3. You reply:**
```
LGTM
```

**4. Night Runner creates PR (next run):**
```
PR #42: fix: Add dark mode support
- Creates draft PR
- Links "Fixes #41"
```

**5. You review, merge, done!**

## Requirements

- **macOS** (uses launchd for scheduling)
- **gh CLI** (`brew install gh && gh auth login`)
- **Claude CLI** (with active subscription)
- **Git** (local clone of your repo)

## Files

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
