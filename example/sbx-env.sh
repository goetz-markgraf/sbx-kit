#!/usr/bin/env bash
# Wrapper for `sbx env`. Prepares two host directories and passes their paths.
#   ./sbx-env.sh plan
#   ./sbx-env.sh run [-- bash]
#   ./sbx-env.sh rm
# SBX_HISTORY_ROOT overrides ~/.sbx-history.
# SBX_OPENCODE_CONFIG overrides ~/.config/opencode (the host config to copy from).
set -euo pipefail

cd "$(dirname "$0")"

# Sandbox name: `name:` from sbxenv.yaml (quotes and trailing comment removed),
# overridden by --name <x> or --name=<x> (before any `--`).
name=$(sed -E -n "s/^name:[[:space:]]*(\"([^\"]*)\"|'([^']*)'|([^[:space:]#]*)).*/\2\3\4/p" sbxenv.yaml | head -n 1)
prev=""
for arg in "$@"; do
  [ "$arg" = "--" ] && break
  [ "$prev" = "--name" ] && name="$arg"
  case "$arg" in --name=*) name="${arg#--name=}" ;; esac
  prev="$arg"
done
[ -n "$name" ] || { echo "no name: in sbxenv.yaml" >&2; exit 1; }
# The name becomes a directory name and is used with rm -rf: no path tricks.
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && "$name" != *..* ]] \
  || { echo "invalid sandbox name '$name' (allowed: letters, digits, . _ -)" >&2; exit 1; }

root="${SBX_HISTORY_ROOT:-$HOME/.sbx-history}"
history_dir="$root/$name"
mkdir -p "$history_dir"

# Expose only allowlisted files of the host config. The directory itself stays
# in place (contents are replaced) so a running sandbox's mount keeps working.
# opencode.json and plugins/ are not copied.
config_src="${SBX_OPENCODE_CONFIG:-$HOME/.config/opencode}"
config_dir="$root/.config-stage/$name"
mkdir -p "$config_dir"
chmod -R u+w "$config_dir"
find "$config_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
for entry in AGENTS.md cli.json agents commands skills themes; do
  [ -e "$config_src/$entry" ] && cp -RL "$config_src/$entry" "$config_dir/$entry"
done

sub="${1:-run}"
[ $# -gt 0 ] && shift

exec sbx env "$sub" \
  --env-arg "historyDir=$history_dir" \
  --env-arg "hostConfigDir=$config_dir" \
  "$@"
