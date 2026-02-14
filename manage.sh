#!/bin/bash
# manage.sh - Manage night-runner launchd job
#
# ============================================================================
# OVERVIEW
# ============================================================================
# Management interface for the night-runner automation system.
# Handles installation, monitoring, and manual execution of the runner.
#
# ============================================================================
# LAUNCHD INTEGRATION
# ============================================================================
# Uses macOS launchd for scheduling:
#
#   com.openonion.night-runner.plist
#        │
#        ├─> StartCalendarInterval (15 times per night)
#        │   ├─> 8 PM, 9 PM, 10 PM, 11 PM
#        │   ├─> 12 AM, 1 AM, 2 AM, ... 10 AM
#        │   └─> Why hourly? Quick response to user LGTM
#        │
#        ├─> EnvironmentVariables
#        │   ├─> PATH (includes ~/.claude/local)
#        │   ├─> HOME
#        │   ├─> http_proxy (localhost:8888)
#        │   └─> https_proxy (localhost:8888)
#        │
#        └─> ProgramArguments
#            └─> /bin/bash run.sh
#
# Installation:
#   1. Generate plist from template (substitute paths)
#   2. Copy to ~/Library/LaunchAgents/
#   3. Load with launchctl
#   4. Runs automatically on schedule
#
# ============================================================================
# COMMANDS
# ============================================================================
#
#   install        Install launchd job (runs hourly 8 PM - 10 AM)
#                  ├─> Checks .env exists
#                  ├─> Generates plist from template
#                  ├─> Copies to ~/Library/LaunchAgents/
#                  └─> Loads with launchctl
#
#   uninstall      Remove launchd job
#                  ├─> Unloads from launchctl
#                  └─> Removes plist file
#
#   status         Show current status
#                  ├─> launchd installation status
#                  ├─> .env configuration
#                  ├─> Skip list (issues to ignore)
#                  └─> Recent log files
#
#   logs           View recent logs (last 50 lines)
#                  └─> Tails logs/night-runner-YYYYMMDD.log
#
#   run            Dry run (preview what would happen)
#                  └─> Calls run.sh --dry-run
#
#   run-one        Process one issue now (interactive)
#                  └─> Calls run.sh --one
#
#   run-issue N    Process specific issue #N now
#                  └─> Calls run.sh --issue N
#
#   clear-skip     Clear skip list (retry failed issues)
#                  └─> Empties logs/.skip-issues
#
# ============================================================================
# FILE STRUCTURE
# ============================================================================
#
#   night-runner/
#   ├── manage.sh                              ← This file
#   ├── run.sh                                 ← Main runner
#   ├── .env                                   ← Config (gitignored)
#   ├── .env.example                           ← Config template
#   ├── com.openonion.night-runner.plist.template  ← launchd template
#   ├── .claude/skills/                        ← Claude Code skills
#   │   ├── night-runner-plan/SKILL.md
#   │   ├── night-runner-implement/SKILL.md
#   │   └── night-runner-update-pr/SKILL.md
#   └── logs/
#       ├── night-runner-YYYYMMDD.log          ← Daily logs
#       └── .skip-issues                       ← Issues to skip
#
# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
#   # Initial setup
#   cp .env.example .env
#   # Edit .env with your repo details
#   ./manage.sh install
#
#   # Check if running
#   ./manage.sh status
#
#   # Test on one issue
#   ./manage.sh run-issue 123
#
#   # View logs
#   ./manage.sh logs
#
#   # Uninstall
#   ./manage.sh uninstall

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

PLIST_NAME="com.openonion.night-runner"
PLIST_TEMPLATE="$SCRIPT_DIR/${PLIST_NAME}.plist.template"
PLIST_GENERATED="$SCRIPT_DIR/${PLIST_NAME}.plist"
PLIST_TARGET="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

# Generate plist from template
generate_plist() {
    sed -e "s|__SCRIPT_DIR__|$SCRIPT_DIR|g" \
        -e "s|__HOME__|$HOME|g" \
        "$PLIST_TEMPLATE" > "$PLIST_GENERATED"
}

case "$1" in
    install)
        echo "Installing night-runner..."

        # Check .env exists
        if [ ! -f "$SCRIPT_DIR/.env" ]; then
            echo "Error: .env not found"
            echo "Copy .env.example to .env and configure it"
            exit 1
        fi

        mkdir -p "$HOME/Library/LaunchAgents"
        mkdir -p "$LOG_DIR"

        # Generate plist from template
        generate_plist

        # Unload if already installed
        if launchctl list | grep -q "$PLIST_NAME"; then
            launchctl unload "$PLIST_TARGET" 2>/dev/null
        fi

        # Copy and load
        cp "$PLIST_GENERATED" "$PLIST_TARGET"
        chmod +x "$SCRIPT_DIR/run.sh"
        launchctl load "$PLIST_TARGET"

        echo ""
        echo "✓ Night Runner installed"
        echo ""
        echo "Schedule: Every hour from 8 PM to 10 AM"
        echo ""
        echo "Commands:"
        echo "  ./manage.sh status     # Check status"
        echo "  ./manage.sh logs       # View logs"
        echo "  ./manage.sh run        # Dry run"
        echo "  ./manage.sh run-one    # Process one issue"
        ;;

    uninstall)
        echo "Uninstalling night-runner..."

        if launchctl list | grep -q "$PLIST_NAME"; then
            launchctl unload "$PLIST_TARGET"
            rm -f "$PLIST_TARGET"
            echo "✓ Night Runner uninstalled"
        else
            echo "- Night Runner not installed"
        fi
        ;;

    status)
        echo "===== Night Runner Status ====="
        echo ""

        if launchctl list | grep -q "$PLIST_NAME"; then
            echo "Status: ✓ Installed"
            echo "Schedule: Every hour from 8 PM to 10 AM"
            launchctl list | grep "$PLIST_NAME"
        else
            echo "Status: ✗ Not installed"
        fi

        echo ""
        echo "===== Config (.env) ====="
        if [ -f "$SCRIPT_DIR/.env" ]; then
            grep -v "^#" "$SCRIPT_DIR/.env" | grep -v "^$"
        else
            echo ".env not found"
        fi

        echo ""
        echo "===== Skip List ====="
        if [ -f "$LOG_DIR/.skip-issues" ] && [ -s "$LOG_DIR/.skip-issues" ]; then
            cat "$LOG_DIR/.skip-issues"
        else
            echo "(empty)"
        fi

        echo ""
        echo "===== Recent Logs ====="
        ls -la "$LOG_DIR"/*.log 2>/dev/null | tail -5 || echo "No logs yet"
        ;;

    logs)
        echo "Recent logs (last 50 lines):"
        echo "============================="

        LOG_FILE="$LOG_DIR/night-runner-$(date +%Y%m%d).log"
        if [ -f "$LOG_FILE" ]; then
            tail -50 "$LOG_FILE"
        else
            echo "No log for today"
            echo ""
            LATEST=$(ls -t "$LOG_DIR"/night-runner-*.log 2>/dev/null | head -1)
            if [ -n "$LATEST" ]; then
                echo "Latest: $LATEST"
                tail -50 "$LATEST"
            fi
        fi
        ;;

    run)
        echo "Dry run (preview only)..."
        "$SCRIPT_DIR/run.sh" --dry-run
        ;;

    run-one)
        echo "Processing one issue..."
        "$SCRIPT_DIR/run.sh" --one
        ;;

    run-issue)
        if [ -z "$2" ]; then
            echo "Usage: ./manage.sh run-issue <number>"
            exit 1
        fi
        echo "Processing issue #$2..."
        "$SCRIPT_DIR/run.sh" --issue "$2"
        ;;

    clear-skip)
        echo "Clearing skip list..."
        "$SCRIPT_DIR/run.sh" --clear-skip --dry-run
        ;;

    *)
        echo "Usage: $0 {install|uninstall|status|logs|run|run-one|run-issue|clear-skip}"
        echo ""
        echo "Commands:"
        echo "  install      - Install launchd job (8 PM - 10 AM hourly)"
        echo "  uninstall    - Remove launchd job"
        echo "  status       - Check status and config"
        echo "  logs         - View recent logs"
        echo "  run          - Dry run (preview)"
        echo "  run-one      - Process one issue now"
        echo "  run-issue N  - Process specific issue #N"
        echo "  clear-skip   - Clear skip list"
        exit 1
        ;;
esac
