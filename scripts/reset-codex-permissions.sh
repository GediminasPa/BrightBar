#!/bin/bash
set -euo pipefail

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="$HOME/.codex/policy-backups/$timestamp"
mkdir -p "$backup_dir"

config="$HOME/.codex/config.toml"
if [[ -f "$config" ]]; then
  cp "$config" "$backup_dir/config.toml"
  awk '
    BEGIN {
      print "default_permissions = \":danger-full-access\""
      skipping = 0
    }

    /^\[/ {
      if ($0 ~ /^\[sandbox_workspace_write/ || $0 ~ /^\[permissions/) {
        skipping = 1
      } else {
        skipping = 0
      }
    }

    skipping { next }

    /^[[:space:]]*(permission_profile|default_permissions|sandbox_mode|approval_policy|approvals_reviewer)[[:space:]]*=/ {
      next
    }

    { print }
  ' "$config" > "$config.tmp"
  mv "$config.tmp" "$config"
else
  printf 'default_permissions = ":danger-full-access"\n' > "$config"
fi

# Disable reversible machine-wide policy files if this Mac has them.
for policy in /etc/codex/requirements.toml /etc/codex/managed_config.toml; do
  if [[ -f "$policy" ]]; then
    sudo cp "$policy" "$backup_dir/$(basename "$policy")"
    sudo mv "$policy" "$policy.disabled-$timestamp"
  fi
done

# Back up and clear locally-written managed preference payloads. MDM-enforced
# values may reappear automatically; the script reports that case below.
defaults export com.openai.codex "$backup_dir/com.openai.codex.plist" >/dev/null 2>&1 || true
defaults delete com.openai.codex requirements_toml_base64 >/dev/null 2>&1 || true
defaults delete com.openai.codex config_toml_base64 >/dev/null 2>&1 || true

echo "Codex permission and sandbox overrides were reset."
echo "Backup: $backup_dir"
echo
echo "Start Codex with: codex --yolo"
echo "If it still reports a required workspace-only profile, that policy is cloud-managed by the signed-in ChatGPT workspace and must be removed in workspace administration or by switching accounts/workspaces."
