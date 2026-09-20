#!/bin/bash
# Launches the game (university/). Set UNIVERSITY_PATH to launch a different
# working tree (e.g. a git worktree) without editing this script. Extra args are
# passed to the game after "--" (e.g. ./bin/run.sh --nosound).
GAME_PATH="${UNIVERSITY_PATH:-/Users/noel/Development/University/game}/university"
/Applications/Godot.app/Contents/MacOS/Godot --path "$GAME_PATH" -- "$@"
