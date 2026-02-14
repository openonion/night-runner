# Night Runner - Claude Code Instructions

## When User Pastes GitHub URL or Install Prompt

If the user pastes:
- `https://github.com/openonion/night-runner`
- Or the install prompt from INSTALL_PROMPT.md
- Or asks to "install Night Runner"

Then follow these steps:

### Step 0: Clone the Repository (if not already done)

```bash
git clone https://github.com/openonion/night-runner.git ~/night-runner
cd ~/night-runner
```

Now continue with the setup process below.

## When User Wants to Set Up Night Runner

If the user asks to "set up", "install", "configure", or "get started" with Night Runner:

1. **Read SETUP_GUIDE.md** - This contains the complete interactive setup process
2. **Follow the steps in order** - Guide user through each step
3. **Ask questions interactively** - One at a time, with clear defaults
4. **Validate as you go** - Check if tools exist, paths are valid, repos are accessible
5. **Be encouraging** - Setup should feel easy and welcoming

## Key Files

- `SETUP_GUIDE.md` - Interactive setup instructions (READ THIS FIRST)
- `.env.example` - Template configuration
- `run.sh` - Main automation script
- `manage.sh` - Installation and scheduling
- `.claude/skills/` - Night Runner skills (must be linked to ~/.claude/skills/)

## Setup Workflow

```
User: "Help me set up Night Runner"
  ↓
Read SETUP_GUIDE.md
  ↓
Show welcome message
  ↓
Check prerequisites (gh CLI, auth)
  ↓
Link skills to ~/.claude/skills/
  ↓
Ask configuration questions interactively
  ↓
Create .env file
  ↓
Offer to create test issue
  ↓
Guide through first run
  ↓
Show success summary
```

## Important Notes

- Always validate repo exists before writing to .env: `gh repo view <repo>`
- Create directories that don't exist (worktree base, logs, etc.)
- Explain what each configuration option does
- Provide sensible defaults for everything
- Test the configuration before declaring success
- Be friendly and use the OpenOnion 🧅 branding

## After Setup

Once setup is complete, users can:
- Run manually: `./run.sh --issue <number>`
- Set up scheduling: `./manage.sh install` (macOS) or cron (Linux)
- See full docs in README.md

## Troubleshooting

If user has issues:
- Check `gh auth status` - most common problem
- Verify repo path exists and is a git repo
- Check logs in `logs/night-runner-*.log`
- Ensure skills are properly linked: `ls -la ~/.claude/skills/night-runner-*`
