#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
#
# test-lumen-service.sh - the unit file install.sh writes for Lumen.
#
# The service is what makes Lumen be there on the first Steam launch instead of
# after a few restarts, so the parts worth pinning are that it starts the right
# binary with the right dirs, survives a crash (Restart=on-failure), and is actually
# enabled. systemctl is stubbed: this must not touch the real user manager.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="$SCRIPT_DIR/../install.sh"

failures=0
check() { # $1 desc  $2 result(0/1)
	if [ "$2" -eq 0 ]; then printf 'ok:   %s\n' "$1"
	else printf 'FAIL: %s\n' "$1"; failures=$((failures+1)); fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_CONFIG_HOME="$WORK/config"
mkdir -p "$HOME" "$WORK/bin"

# Stub systemctl: record the calls, always succeed.
CALLS="$WORK/systemctl.calls"
cat >"$WORK/bin/systemctl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$SYSTEMCTL_CALLS"
exit 0
EOF
chmod 755 "$WORK/bin/systemctl"
export SYSTEMCTL_CALLS="$CALLS"
export PATH="$WORK/bin:$PATH"

export SLSPLUGIN_LIB_ONLY=1
# shellcheck disable=SC1090
source "$INSTALL_SH" >/dev/null 2>&1

UNIT="$XDG_CONFIG_HOME/systemd/user/lumen.service"

# --- default: service written, enabled and started ---------------------------
OPT_LUMEN_SERVICE=1
install_lumen_service >/dev/null 2>&1
[ -f "$UNIT" ] && check "unit file written" 0 || check "unit file written" 1
grep -q '^ExecStart=%h/.local/share/Lumen/lumen$' "$UNIT" \
	&& check "ExecStart points at Lumen" 0 || check "ExecStart points at Lumen" 1
grep -q '^Environment=LUMEN_LUA_DIR=%h/.local/share/Lumen/lua$' "$UNIT" \
	&& check "lua dir passed through" 0 || check "lua dir passed through" 1
grep -q '^Environment=LUMEN_BACKEND_DIR=%h/.local/share/Lumen/luatools/backend$' "$UNIT" \
	&& check "backend dir passed through" 0 || check "backend dir passed through" 1
grep -q '^Restart=on-failure$' "$UNIT" \
	&& check "restarts after a crash" 0 || check "restarts after a crash" 1
grep -q '^Environment=LUMEN_STEAM_GRACE=120$' "$UNIT" \
	&& check "idle exit is short enough to not linger" 0 \
	|| check "idle exit is short enough to not linger" 1
grep -q '^WantedBy=default.target$' "$UNIT" \
	&& check "starts at login" 0 || check "starts at login" 1
grep -q 'enable --now lumen.service' "$CALLS" 2>/dev/null \
	&& check "enabled and started" 0 || check "enabled and started" 1
grep -q 'daemon-reload' "$CALLS" 2>/dev/null \
	&& check "daemon reloaded" 0 || check "daemon reloaded" 1

# --- opt-out ----------------------------------------------------------------
mkdir -p "$(dirname "$UNIT")"
printf '[Unit]\nDescription=stale\n' >"$UNIT"
rm -f "$CALLS"
OPT_LUMEN_SERVICE=0
install_lumen_service >/dev/null 2>&1
[ -f "$UNIT" ] && check "--no-lumen-service removes an old unit" 1 \
	|| check "--no-lumen-service removes an old unit" 0
grep -q 'disable --now lumen.service' "$CALLS" 2>/dev/null \
	&& check "--no-lumen-service disables the old unit" 0 \
	|| check "--no-lumen-service disables the old unit" 1

# --- unit syntax, when systemd-analyze is around ----------------------------
OPT_LUMEN_SERVICE=1
install_lumen_service >/dev/null 2>&1
if command -v systemd-analyze >/dev/null 2>&1; then
	if systemd-analyze --user verify "$UNIT" >/dev/null 2>&1; then
		check "systemd accepts the unit" 0
	else
		# verify wants a user manager in some environments; report the output.
		echo "  note: systemd-analyze --user verify unavailable/failed here"
		systemd-analyze --user verify "$UNIT" 2>&1 | sed 's/^/    /' | head -5
	fi
fi

echo ""
if [ "$failures" -eq 0 ]; then echo "ALL PASS"; exit 0; fi
echo "$failures CHECK(S) FAILED"; exit 1
