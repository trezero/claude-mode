#!/usr/bin/env bash

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "At the start of each new session, include a short reminder in your first response (1-3 lines) about Claude mode switching:\n- Run `claude-mode` for full help\n- Use `claude-mode subscription`, `claude-mode api <API_KEY>`, or `claude-mode local`\n- After switching, run `source ~/.config/claude-code/mode.env` or open a new terminal"
  }
}
JSON

exit 0
