#!/usr/bin/env bash
# Thin wrapper for `sbx env`. Only passes the $HOME-based history path, because
# sbxenv.yaml does not expand $HOME or ~. All host work (history dir, config
# staging) is done by lifecycle.initialize in sbxenv.yaml, which `sbx env plan`
# shows and you approve.
#   sbx-env.sh plan
#   sbx-env.sh run [-- bash]
#   sbx-env.sh rm
# Location-independent: run it from the directory containing sbxenv.yaml
# (sbx env looks in the current directory). Put the script anywhere, e.g. on PATH.
# Sandbox name: --env-arg sandboxName=<x> (default in sbxenv.yaml).
# SBX_HISTORY_ROOT overrides ~/.sbx-history.
set -euo pipefail

[ -f sbxenv.yaml ] || { echo "no sbxenv.yaml in $PWD" >&2; exit 1; }

# --name would rename the sandbox but not its history directory.
for arg in "$@"; do
  [ "$arg" = "--" ] && break
  case "$arg" in
    --name | --name=*) echo "use --env-arg sandboxName=<x> instead of --name" >&2; exit 1 ;;
  esac
done

sub="${1:-run}"
[ $# -gt 0 ] && shift

exec sbx env "$sub" \
  --env-arg "historyRoot=${SBX_HISTORY_ROOT:-$HOME/.sbx-history}" \
  "$@"
