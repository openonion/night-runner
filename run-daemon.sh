#!/bin/bash
# Wrapper to allow launchd to start multiple concurrent instances.
# AbandonProcessGroup=true in plist lets the child outlive this wrapper.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

LOGFILE="logs/daemon-$(date +%Y%m%d-%H%M%S)-$$.log"

# Spawn run.sh in background - launchd won't kill it (AbandonProcessGroup=true)
/bin/bash "$SCRIPT_DIR/run.sh" >> "$LOGFILE" 2>&1 &

# Exit immediately so launchd starts the next instance in 30 seconds
exit 0
