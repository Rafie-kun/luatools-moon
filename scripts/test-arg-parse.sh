#!/usr/bin/env bash
# Unit test for install.sh's command-line option parsing.
#
# Why this exists
# ---------------
# The installer grew a `--noplugin` flag (curl ... | bash -s -- --noplugin) that
# installs only the runtime stack (slsteam-moon + Lumen) and skips both the
# LuaTools plugin and the optional CloudRedirect prompt. parse_args is the pure
# option parser behind it; this pins its behaviour (defaults, component update
# channels, the flag, --help, invalid-option handling, and that state resets
# between calls) without running the full installer.
#
# Run: bash scripts/test-arg-parse.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="$SCRIPT_DIR/../install.sh"

failures=0
check() { # $1 desc  $2 result(0/1)
	if [ "$2" -eq 0 ]; then printf 'ok:   %s\n' "$1"
	else printf 'FAIL: %s\n' "$1"; failures=$((failures+1)); fi
}

export SLSPLUGIN_LIB_ONLY=1
# shellcheck disable=SC1090
source "$INSTALL_SH" >/dev/null 2>&1

# --- defaults ---------------------------------------------------------------
parse_args; check "no args: returns 0" $?
[ "$OPT_NOPLUGIN" = 0 ]; check "no args: OPT_NOPLUGIN=0" $?
[ "$OPT_HELP" = 0 ];     check "no args: OPT_HELP=0" $?
[ "$OPT_SLS_CHANNEL" = stable ];    check "no args: slsteam channel defaults to stable" $?
[ "$OPT_PLUGIN_CHANNEL" = stable ]; check "no args: plugin channel defaults to stable" $?
[ "$OPT_LUMEN_CHANNEL" = stable ];  check "no args: Lumen channel defaults to stable" $?

# --- per-component channels -------------------------------------------------
parse_args \
	--slsteam-channel beta \
	--plugin-channel stable \
	--lumen-channel beta
check "channel options: return 0" $?
[ "$OPT_SLS_CHANNEL" = beta ];      check "channel options: slsteam beta" $?
[ "$OPT_PLUGIN_CHANNEL" = stable ]; check "channel options: plugin stable" $?
[ "$OPT_LUMEN_CHANNEL" = beta ];    check "channel options: Lumen beta" $?

if parse_args --lumen-channel; then r=1; else r=0; fi
check "missing channel value: returns non-zero" "$r"
[ "$OPT_BAD_ARG" = "--lumen-channel" ]; check "missing channel value: records option" $?

if parse_args --plugin-channel nightly; then r=1; else r=0; fi
check "invalid channel value: returns non-zero" "$r"
[ "$OPT_BAD_ARG" = "--plugin-channel nightly" ]; check "invalid channel value: records option and value" $?

# --- --noplugin -------------------------------------------------------------
parse_args --noplugin; check "--noplugin: returns 0" $?
[ "$OPT_NOPLUGIN" = 1 ]; check "--noplugin: OPT_NOPLUGIN=1" $?

# --- Lumen user service -----------------------------------------------------
# On by default (Lumen should already be up when Steam starts, no matter which
# launcher started it); the flag is there for people who want the wrapper to
# own the sidecar.
parse_args; check "no args: returns 0 (Lumen service)" $?
[ "$OPT_LUMEN_SERVICE" = 1 ]; check "no args: Lumen service is installed" $?

parse_args --no-lumen-service; check "--no-lumen-service: returns 0" $?
[ "$OPT_LUMEN_SERVICE" = 0 ]; check "--no-lumen-service: OPT_LUMEN_SERVICE=0" $?

parse_args --no-lumen-service; parse_args
[ "$OPT_LUMEN_SERVICE" = 1 ]; check "Lumen service setting resets to on" $?

parse_args --lumen-service
[ "$OPT_LUMEN_SERVICE" = 1 ]; check "--lumen-service: explicitly on" $?

# --- Millennium -------------------------------------------------------------
# The installer no longer removes Millennium on its own; the bare flag keeps
# its old meaning (drop the loader, keep the settings) and "all" opts out.
parse_args; check "no args: returns 0 (Millennium)" $?
[ "$OPT_MILLENNIUM" = keep ]; check "no args: Millennium is left alone" $?

parse_args --keep-millennium
check "--keep-millennium: returns 0" $?
[ "$OPT_MILLENNIUM" = configs ]; check "--keep-millennium: bare flag means configs" $?

parse_args --keep-millennium all
check "--keep-millennium all: returns 0" $?
[ "$OPT_MILLENNIUM" = keep ]; check "--keep-millennium all: Millennium stays" $?

parse_args --keep-millennium=configs
[ "$OPT_MILLENNIUM" = configs ]; check "--keep-millennium=configs: configs" $?

parse_args --keep-millennium=all
[ "$OPT_MILLENNIUM" = keep ]; check "--keep-millennium=all: Millennium stays" $?

parse_args --keep-millennium --noplugin
[ "$OPT_MILLENNIUM" = configs ]; check "--keep-millennium alone does not eat the next flag" $?
[ "$OPT_NOPLUGIN" = 1 ];        check "--keep-millennium then --noplugin: both applied" $?

if parse_args --keep-millennium=bogus; then r=1; else r=0; fi
check "--keep-millennium=bogus: returns non-zero" "$r"

parse_args --remove-millennium
[ "$OPT_MILLENNIUM" = remove ]; check "--remove-millennium: full removal" $?

parse_args --remove-millennium; parse_args
[ "$OPT_MILLENNIUM" = keep ]; check "Millennium mode resets to keep" $?

# --- --help / -h ------------------------------------------------------------
parse_args --help; [ "$OPT_HELP" = 1 ]; check "--help: OPT_HELP=1" $?
parse_args -h;     [ "$OPT_HELP" = 1 ]; check "-h: OPT_HELP=1" $?

# --- state resets between calls ---------------------------------------------
parse_args --noplugin --slsteam-channel beta --plugin-channel beta --lumen-channel beta; parse_args
[ "$OPT_NOPLUGIN" = 0 ]; check "OPT_NOPLUGIN resets to 0 on a fresh parse" $?
[ "$OPT_SLS_CHANNEL" = stable ];    check "slsteam channel resets to stable" $?
[ "$OPT_PLUGIN_CHANNEL" = stable ]; check "plugin channel resets to stable" $?
[ "$OPT_LUMEN_CHANNEL" = stable ];  check "Lumen channel resets to stable" $?

# --- unknown option ---------------------------------------------------------
if parse_args --bogus; then r=1; else r=0; fi
check "unknown option: returns non-zero" "$r"
[ "$OPT_BAD_ARG" = "--bogus" ]; check "unknown option: recorded in OPT_BAD_ARG" $?

echo ""
if [ "$failures" -eq 0 ]; then echo "ALL PASS"; exit 0; fi
echo "$failures CHECK(S) FAILED"; exit 1
