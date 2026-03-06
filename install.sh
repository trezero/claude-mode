#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/assets"

START_MARKER="# >>> claude-mode >>>"
END_MARKER="# <<< claude-mode <<<"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_BLUE=$'\033[34m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
else
  C_RESET=""
  C_BOLD=""
  C_BLUE=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
fi

info() {
  printf "%s%s%s\n" "$C_BLUE" "$1" "$C_RESET"
}

success() {
  printf "%s%s%s\n" "$C_GREEN" "$1" "$C_RESET"
}

warn() {
  printf "%s%s%s\n" "$C_YELLOW" "$1" "$C_RESET"
}

fatal() {
  printf "%s%s%s\n" "$C_RED" "$1" "$C_RESET" >&2
  exit 1
}

prompt_input() {
  local prompt="$1"
  local default="${2:-}"
  local value

  if [ -n "$default" ]; then
    printf "%s [%s]: " "$prompt" "$default" >&2
  else
    printf "%s: " "$prompt" >&2
  fi

  read -r value || true
  printf "%s" "${value:-$default}"
}

prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local answer

  while true; do
    if [ "$default" = "y" ]; then
      printf "%s [Y/n]: " "$prompt" >&2
    else
      printf "%s [y/N]: " "$prompt" >&2
    fi

    read -r answer || true
    answer="${answer:-$default}"

    case "$answer" in
      y|Y|yes|YES)
        return 0
        ;;
      n|N|no|NO)
        return 1
        ;;
      *)
        warn "Please answer y or n."
        ;;
    esac
  done
}

backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)"
    cp "$file" "$file.bak-$stamp"
  fi
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || fatal "Required command not found: $cmd"
}

detect_existing_installation() {
  local install_dir="${1:-$HOME/.local/bin}"
  local bin_path="$install_dir/claude-mode"
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/claude-code"
  local mode_file="$config_dir/mode"
  local mode_env="$config_dir/mode.env"
  local claude_hook="$HOME/.claude/hooks/claude-mode-reminder-session-start.sh"
  local claude_command="$HOME/.claude/commands/claude-mode.md"
  
  local found=0
  local details=""
  
  if [ -f "$bin_path" ]; then
    found=1
    details="${details}  - Binary: $bin_path\n"
  fi
  
  if [ -f "$mode_file" ] || [ -f "$mode_env" ]; then
    found=1
    details="${details}  - Configuration: $config_dir\n"
  fi
  
  if [ -f "$claude_hook" ] || [ -f "$claude_command" ]; then
    found=1
    details="${details}  - Claude integration: ~/.claude/\n"
  fi
  
  if [ $found -eq 1 ]; then
    printf "%s" "$details"
    return 0
  else
    return 1
  fi
}

check_platform() {
  local os
  os="$(uname -s)"
  case "$os" in
    Linux|Darwin)
      ;;
    *)
      fatal "Unsupported OS: $os. This installer supports Linux and macOS only."
      ;;
  esac
}

upsert_marked_block() {
  local target_file="$1"
  local block_file="$2"

  mkdir -p "$(dirname "$target_file")"
  [ -f "$target_file" ] || touch "$target_file"

  python3 - "$target_file" "$block_file" "$START_MARKER" "$END_MARKER" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
block_path = pathlib.Path(sys.argv[2])
start = sys.argv[3]
end = sys.argv[4]

text = path.read_text(encoding="utf-8") if path.exists() else ""
block = block_path.read_text(encoding="utf-8").rstrip("\n")
new_block = f"{start}\n{block}\n{end}"

start_idx = text.find(start)
end_idx = text.find(end)

if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
    end_idx += len(end)
    updated = text[:start_idx].rstrip("\n") + "\n\n" + new_block + "\n"
    suffix = text[end_idx:].lstrip("\n")
    if suffix:
        updated += "\n" + suffix
else:
    updated = text.rstrip("\n")
    if updated:
        updated += "\n\n"
    updated += new_block + "\n"

path.write_text(updated, encoding="utf-8")
PY
}

install_binary() {
  local install_dir="$1"
  local is_reinstall="${2:-false}"
  local target="$install_dir/claude-mode"

  mkdir -p "$install_dir"
  
  if [ "$is_reinstall" = "true" ] && [ -f "$target" ]; then
    backup_file "$target"
    info "Backed up existing binary"
  fi
  
  cp "$ASSETS_DIR/bin/claude-mode" "$target"
  chmod +x "$target"

  printf "%s" "$target"
}

write_temp_file() {
  local output_file="$1"
  shift
  cat > "$output_file" <<EOF_BLOCK
$*
EOF_BLOCK
}

configure_shell_integration() {
  local install_dir="$1"
  local is_reinstall="${2:-false}"
  local -a files=()

  echo
  info "Step 2/5: Shell integration"
  
  if [ "$is_reinstall" = "true" ]; then
    if prompt_yes_no "Update shell integration?" "n"; then
      echo "Choose which shell startup file(s) to update:"
    else
      warn "Skipping shell integration update."
      return 0
    fi
  fi
  
  echo "Choose which shell startup file(s) to update:"
  echo "  [1] ~/.bashrc"
  echo "  [2] ~/.zshrc"
  echo "  [3] Both"
  echo "  [4] Custom path"
  echo "  [5] Skip"

  local choice
  while true; do
    choice="$(prompt_input "Selection" "3")"
    case "$choice" in
      1)
        files+=("$HOME/.bashrc")
        break
        ;;
      2)
        files+=("$HOME/.zshrc")
        break
        ;;
      3)
        files+=("$HOME/.bashrc" "$HOME/.zshrc")
        break
        ;;
      4)
        files+=("$(prompt_input "Custom shell file path")")
        break
        ;;
      5)
        warn "Skipping shell integration. You will need to source ~/.config/claude-code/mode.env manually."
        return 0
        ;;
      *)
        warn "Please choose 1, 2, 3, 4, or 5."
        ;;
    esac
  done

  local block_file
  block_file="$(mktemp)"
  write_temp_file "$block_file" "if [ -f \"\$HOME/.config/claude-code/mode.env\" ]; then
    . \"\$HOME/.config/claude-code/mode.env\"
else
    unset ANTHROPIC_API_KEY
    unset ANTHROPIC_AUTH_TOKEN
    unset ANTHROPIC_BASE_URL
    unset LITELLM_MASTER_KEY
fi"

  local path_block_file
  path_block_file="$(mktemp)"
  write_temp_file "$path_block_file" "case \":\$PATH:\" in
  *\":$install_dir:\"*) ;;
  *) export PATH=\"$install_dir:\$PATH\" ;;
esac"

  local file
  for file in "${files[@]}"; do
    if [ -f "$file" ]; then
      backup_file "$file"
    fi
    upsert_marked_block "$file" "$block_file"
    success "Updated shell integration in $file"

    if ! grep -q "# >>> claude-mode-path >>>" "$file" 2>/dev/null; then
      python3 - "$file" "$path_block_file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
block = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8").rstrip("\n")
start = "# >>> claude-mode-path >>>"
end = "# <<< claude-mode-path <<<"
text = path.read_text(encoding="utf-8")
entry = f"{start}\n{block}\n{end}\n"

if start in text and end in text:
    s = text.find(start)
    e = text.find(end)
    if e > s:
      e += len(end)
      text = text[:s].rstrip("\n") + "\n\n" + entry + ("\n" + text[e:].lstrip("\n") if text[e:].strip() else "")
else:
    text = text.rstrip("\n") + "\n\n" + entry

path.write_text(text, encoding="utf-8")
PY
      success "Ensured PATH block exists in $file"
    fi
  done

  rm -f "$block_file" "$path_block_file"
}

configure_claude_global() {
  local is_reinstall="${1:-false}"
  
  echo
  info "Step 3/5: Global Claude helpers"

  local default_answer="y"
  if [ "$is_reinstall" = "true" ]; then
    default_answer="n"
  fi

  if ! prompt_yes_no "Install global SessionStart reminder hook and /claude-mode command?" "$default_answer"; then
    warn "Skipping global Claude helper installation."
    return 0
  fi

  local claude_dir="$HOME/.claude"
  local hooks_dir="$claude_dir/hooks"
  local commands_dir="$claude_dir/commands"
  local settings_file="$claude_dir/settings.json"
  local hook_target="$hooks_dir/claude-mode-reminder-session-start.sh"
  local command_target="$commands_dir/claude-mode.md"

  mkdir -p "$hooks_dir" "$commands_dir"

  [ -f "$hook_target" ] && backup_file "$hook_target"
  [ -f "$command_target" ] && backup_file "$command_target"

  cp "$ASSETS_DIR/claude/hooks/claude-mode-reminder-session-start.sh" "$hook_target"
  chmod +x "$hook_target"

  cp "$ASSETS_DIR/claude/commands/claude-mode.md" "$command_target"

  if [ -f "$settings_file" ]; then
    backup_file "$settings_file"
  else
    mkdir -p "$(dirname "$settings_file")"
    printf "{}\n" > "$settings_file"
  fi

  python3 - "$settings_file" "$hook_target" <<'PY'
import json
import pathlib
import sys

settings_path = pathlib.Path(sys.argv[1])
hook_command = sys.argv[2]

try:
    data = json.loads(settings_path.read_text(encoding="utf-8"))
except Exception as exc:
    raise SystemExit(f"Failed to parse {settings_path}: {exc}")

if not isinstance(data, dict):
    data = {}

hooks = data.setdefault("hooks", {})
if not isinstance(hooks, dict):
    hooks = {}
    data["hooks"] = hooks

session_start = hooks.setdefault("SessionStart", [])
if not isinstance(session_start, list):
    session_start = []
    hooks["SessionStart"] = session_start

exists = False
for item in session_start:
    if not isinstance(item, dict):
        continue
    subhooks = item.get("hooks", [])
    if not isinstance(subhooks, list):
        continue
    for sub in subhooks:
        if isinstance(sub, dict) and sub.get("type") == "command" and sub.get("command") == hook_command:
            exists = True
            break
    if exists:
        break

if not exists:
    session_start.append(
        {
            "hooks": [
                {
                    "type": "command",
                    "command": hook_command,
                }
            ]
        }
    )

settings_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

  success "Installed global hook: $hook_target"
  success "Installed global command: $command_target"
  success "Updated Claude settings: $settings_file"
}

configure_default_mode() {
  local claude_mode_bin="$1"
  local is_reinstall="${2:-false}"

  echo
  info "Step 4/5: Choose default Claude mode"
  
  if [ "$is_reinstall" = "true" ]; then
    if ! prompt_yes_no "Reconfigure default Claude mode?" "n"; then
      warn "Keeping existing mode configuration."
      return 0
    fi
  fi
  
  echo "  [1] subscription (Claude Code subscription / OAuth)"
  echo "  [2] api          (direct Anthropic API billing)"
  echo "  [3] local        (local-compatible endpoint, e.g. Ollama)"

  local choice
  while true; do
    choice="$(prompt_input "Default mode" "1")"
    case "$choice" in
      1)
        "$claude_mode_bin" subscription >/dev/null
        success "Default mode set to subscription."
        break
        ;;
      2)
        local api_key base_url
        printf "Anthropic API key (input hidden): " >&2
        read -rs api_key
        echo >&2
        [ -n "$api_key" ] || fatal "API key is required for api mode."
        base_url="$(prompt_input "Anthropic base URL" "https://api.anthropic.com")"
        "$claude_mode_bin" api-key set "$api_key" >/dev/null
        "$claude_mode_bin" api "" "$base_url" >/dev/null
        success "Default mode set to api."
        break
        ;;
      3)
        local base_url auth_token api_key
        base_url="$(prompt_input "Local base URL" "http://localhost:11434")"
        auth_token="$(prompt_input "Local auth token" "ollama")"
        api_key="$(prompt_input "Local API key placeholder" "unused")"
        "$claude_mode_bin" local "$base_url" "$auth_token" "$api_key" >/dev/null
        success "Default mode set to local."
        break
        ;;
      *)
        warn "Please choose 1, 2, or 3."
        ;;
    esac
  done
}

show_summary() {
  local bin_path="$1"

  echo
  info "Step 5/5: Complete"
  success "Installation complete."
  echo
  echo "Installed binary: $bin_path"
  echo "Mode state file: ${XDG_CONFIG_HOME:-$HOME/.config}/claude-code/mode"
  echo "Mode env file:   ${XDG_CONFIG_HOME:-$HOME/.config}/claude-code/mode.env"
  echo
  echo "Next steps:"
  echo "  1) Open a new terminal OR run: source ${XDG_CONFIG_HOME:-$HOME/.config}/claude-code/mode.env"
  echo "  2) Run: claude-mode"
  echo "  3) Configure/update API key anytime: claude-mode api-key"
  echo "  4) In Claude Code, use /claude-mode anytime for a reminder"
}

main() {
  echo
  printf "%s%sClaude Mode Installer%s\n" "$C_BOLD" "$C_BLUE" "$C_RESET"
  echo "This installer configures the full claude-mode workflow for Linux/macOS."

  check_platform
  require_cmd bash
  require_cmd python3

  [ -d "$ASSETS_DIR" ] || fatal "Missing assets directory: $ASSETS_DIR"
  [ -f "$ASSETS_DIR/bin/claude-mode" ] || fatal "Missing asset: $ASSETS_DIR/bin/claude-mode"

  local is_reinstall="false"
  local install_dir="$HOME/.local/bin"
  
  echo
  if existing_details="$(detect_existing_installation "$install_dir")"; then
    warn "Existing claude-mode installation detected:"
    printf "%b" "$existing_details"
    echo
    
    if prompt_yes_no "Do you want to reinstall/update?" "y"; then
      is_reinstall="true"
      info "Proceeding with reinstall..."
    else
      info "Installation cancelled."
      exit 0
    fi
  fi

  echo
  info "Step 1/5: Install claude-mode command"
  
  if [ "$is_reinstall" = "false" ]; then
    install_dir="$(prompt_input "Install directory" "$HOME/.local/bin")"
  else
    info "Using existing install directory: $install_dir"
  fi
  
  local bin_path
  bin_path="$(install_binary "$install_dir" "$is_reinstall")"
  
  if [ "$is_reinstall" = "true" ]; then
    success "Updated claude-mode at $bin_path"
  else
    success "Installed claude-mode at $bin_path"
  fi

  configure_shell_integration "$install_dir" "$is_reinstall"
  configure_claude_global "$is_reinstall"
  configure_default_mode "$bin_path" "$is_reinstall"
  show_summary "$bin_path"
}

main "$@"
