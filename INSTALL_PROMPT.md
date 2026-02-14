# One-Click Install for Claude Code

## Copy-Paste Installation

**Just copy this entire prompt and paste into Claude Code:**

```
Install Night Runner (GitHub issue automation) for me:

1. Clone the repository:
   git clone https://github.com/openonion/night-runner.git ~/night-runner
   cd ~/night-runner

2. Link the skills to Claude Code:
   mkdir -p ~/.claude/skills
   ln -sf ~/night-runner/.claude/skills/night-runner-plan ~/.claude/skills/
   ln -sf ~/night-runner/.claude/skills/night-runner-implement ~/.claude/skills/
   ln -sf ~/night-runner/.claude/skills/night-runner-update-pr ~/.claude/skills/

3. Check prerequisites:
   - Verify gh CLI is installed and authenticated
   - If not, guide me to install and authenticate

4. Ask me these questions to configure .env:
   - What's your GitHub repository? (format: owner/repo)
   - Where is your local clone of this repo? (default: $HOME/project/<repo-name>)
   - What label should trigger automation? (default: "auto")
   - Where should worktrees be created? (default: $HOME/worktrees)

5. Create the .env file with my answers

6. Ask if I want to create a test issue and run Night Runner once

7. Show me how to use it and optionally set up automation

Let's get started!
```

---

## Alternative: Just the GitHub URL

You can also just paste the GitHub URL:

```
https://github.com/openonion/night-runner

Please install and set this up for me. It's a GitHub issue automation tool.
Ask me questions to configure it properly.
```

Claude Code will:
- Clone the repository
- Read the README and SETUP_GUIDE.md
- Guide you through configuration
- Set everything up

---

## What Happens

1. **Clone** - Repository downloaded to `~/night-runner`
2. **Link Skills** - Night Runner skills available in Claude Code globally
3. **Configure** - Interactive questions to create `.env`
4. **Test** - Optional test issue to verify setup
5. **Done!** - Ready to automate your GitHub issues

## After Installation

Run manually:
```bash
~/night-runner/run.sh --issue <number>
```

Set up automation (optional):
```bash
~/night-runner/manage.sh install  # macOS
```

Or add to cron (Linux):
```bash
0 * * * * cd ~/night-runner && ./run.sh >> logs/cron.log 2>&1
```
