#!/usr/bin/env bash
# Unit tests for per-component Stable/Beta artifact selection in install.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="$SCRIPT_DIR/../install.sh"

failures=0
check() {
	if [ "$2" -eq 0 ]; then printf 'ok:   %s\n' "$1"
	else printf 'FAIL: %s\n' "$1"; failures=$((failures+1)); fi
}

export SLSPLUGIN_LIB_ONLY=1
# shellcheck disable=SC1090
source "$INSTALL_SH" >/dev/null 2>&1

{ [ "$SLS_BETA_PATH" = "dist/slsteam-moon-linux.zip" ] &&
  [ "$PLUGIN_BETA_PATH" = "dist/luatools-linux.zip" ] &&
  [ "$LUMEN_BETA_PATH" = "dist/lumen-linux.zip" ]; }
check "each component has a future-compatible beta artifact path" $?

# The fork publishes the payload, so it is the only source probed by default:
# ogb4n/slssteam-moon-x64 answers 404 and must not cost a request per install.
{ [ "$SLS_REPO" = "Rafie-kun/slsteam-moon" ] &&
  [ -z "$SLS_REPO_FALLBACK" ]; }
check "the fork is the default source and no dead fallback is probed" $?

{ printf '%s\n' "slssteam-moon-x64-linux-3.2.zip" | grep -Eq "$SLS_ASSET_GLOB" &&
  printf '%s\n' "slsteam-moon-linux-3.2.zip" | grep -Eq "$SLS_ASSET_GLOB" &&
  ! printf '%s\n' "slsteam-moon-linux-3.2.zip.sha256" | grep -Eq "$SLS_ASSET_GLOB"; }
check "release asset glob accepts both payload names" $?

# The installer refuses a release whose payload the client cannot load.
ELF_TMP="$(mktemp)"
printf '\177ELF\001\001\001 fake 32-bit object' >"$ELF_TMP"
{ [ "$(elf_class "$ELF_TMP")" = 1 ] && [ "$(elf_class /bin/true)" = 2 ] &&
  [ -z "$(elf_class /etc/hostname)" ]; }
check "elf_class tells 32-bit, 64-bit and non-ELF apart" $?
rm -f "$ELF_TMP"

MOCK_API_FAIL=0
MOCK_API_JSON='{"sha":"0123456789abcdef","size":4321,"download_url":"https://raw.example/lumen.zip"}'
API_URL_FILE="$(mktemp)"
trap 'rm -f "$API_URL_FILE"' EXIT
api_get() {
	printf '%s' "$1" >"$API_URL_FILE"
	[ "$MOCK_API_FAIL" = 1 ] && return 1
	printf '%s' "$MOCK_API_JSON"
}

info="$(beta_asset_info "swwayps/lumen" "dist/lumen-linux.zip")"; rc=$?
{ [ "$rc" -eq 0 ] &&
  [ "$(printf '%s' "$info" | jq -r '.tag')" = beta ] &&
  [ "$(printf '%s' "$info" | jq -r '.channel')" = beta ] &&
  [ "$(printf '%s' "$info" | jq -r '.id')" = 0123456789abcdef ] &&
  [ "$(printf '%s' "$info" | jq -r '.download_url')" = https://raw.example/lumen.zip ]; }
check "beta metadata becomes an installable fingerprint" $?
[ "$(cat "$API_URL_FILE")" = "https://api.github.com/repos/swwayps/lumen/contents/dist/lumen-linux.zip?ref=beta" ]
check "beta metadata uses the branch contents endpoint" $?

MOCK_API_JSON='{"message":"Not Found"}'
if beta_asset_info "swwayps/lumen" "dist/lumen-linux.zip" >/dev/null; then r=1; else r=0; fi
check "missing beta artifact is unavailable" "$r"

# Mock stable resolution so selection can be tested without network access.
latest_release_asset_url() { printf 'https://stable.example/component.zip'; }
any_release_asset_url() { printf 'https://stable.example/component-any.zip'; }
release_asset_info() { printf '{"tag":"v9","id":99,"size":9000}'; }
# resolve_component_asset goes through github_release_asset_info; mock that too,
# so the fallback and any-release cases exercise the real selector.
github_release_asset_info() {
	if [ "${3:-latest}" = "any" ]; then
		printf '{"url":"https://stable.example/component-any.zip","tag":"v9","id":99,"size":9000}'
	else
		printf '{"url":"https://stable.example/component.zip","tag":"v9","id":99,"size":9000}'
	fi
}
log_warn() { :; }

MOCK_API_JSON='{"sha":"beta-sha","size":123,"download_url":"https://beta.example/component.zip"}'
resolve_component_asset beta repo dist/component.zip '^component\\.zip$' latest; rc=$?
{ [ "$rc" -eq 0 ] &&
  [ "$RESOLVED_ASSET_URL" = https://beta.example/component.zip ] &&
  [ "$(printf '%s' "$RESOLVED_ASSET_INFO" | jq -r '.channel')" = beta ]; }
check "available beta is selected without resolving Stable" $?

MOCK_API_JSON='{"message":"Not Found"}'
resolve_component_asset beta repo dist/component.zip '^component\\.zip$' latest; rc=$?
{ [ "$rc" -eq 0 ] &&
  [ "$RESOLVED_ASSET_URL" = https://stable.example/component.zip ] &&
  [ "$(printf '%s' "$RESOLVED_ASSET_INFO" | jq -r '.channel')" = stable ]; }
check "missing beta falls back to Stable for that component" $?

MOCK_API_FAIL=0
MOCK_API_JSON='{"sha":"ignored-beta","size":123,"download_url":"https://beta.example/ignored.zip"}'
resolve_component_asset stable repo dist/component.zip '^component\\.zip$' any; rc=$?
{ [ "$rc" -eq 0 ] &&
  [ "$RESOLVED_ASSET_URL" = https://stable.example/component-any.zip ] &&
  [ "$(printf '%s' "$RESOLVED_ASSET_INFO" | jq -r '.channel')" = stable ]; }
check "Stable selection skips beta and supports any-release resolution" $?

# ── mirror manifest: ours first, upstream only as the emergency copy ─────────
DIGEST="$(printf 'a%.0s' {1..64})"
MIRROR_OURS='{"schema":1,"components":{"lumen":{"tag":"v2.12","url":"https://cdn.jsdelivr.net/gh/Rafie-kun/jsdelivr@deadbeef/releases/lumen/v2.12/'"$DIGEST"'/lumen-linux.zip","sha256":"'"$DIGEST"'"}}}'
MIRROR_UPSTREAM='{"schema":1,"components":{"lumen":{"tag":"v2.9","url":"https://cdn.jsdelivr.net/gh/swwayps/jsdelivr@deadbeef/releases/lumen/v2.9/'"$DIGEST"'/lumen-linux.zip","sha256":"'"$DIGEST"'"}}}'
MIRROR_OURS_FAIL=0
api_get() {
	case "$1" in
		*Rafie-kun/jsdelivr*)
			[ "$MIRROR_OURS_FAIL" = 1 ] && return 1
			printf '%s' "$MIRROR_OURS" ;;
		*swwayps/jsdelivr*) printf '%s' "$MIRROR_UPSTREAM" ;;
		*) return 1 ;;
	esac
}
info="$(mirror_release_asset_info lumen)"
check "mirror reads our fork's manifest first" \
	"$([ "$(printf '%s' "$info" | jq -r '.tag')" = v2.12 ]; echo $?)"
MIRROR_OURS_FAIL=1
info="$(mirror_release_asset_info lumen)"
check "an unavailable mirror falls back to upstream" \
	"$([ "$(printf '%s' "$info" | jq -r '.tag')" = v2.9 ]; echo $?)"
MIRROR_OURS_FAIL=0
# An entry pointing at another repository is not ours to trust.
MIRROR_OURS='{"schema":1,"components":{"lumen":{"tag":"v9","url":"https://cdn.jsdelivr.net/gh/swwayps/jsdelivr@deadbeef/x.zip","sha256":"'"$DIGEST"'"}}}'
info="$(mirror_release_asset_info lumen)"
check "mirror rejects an archive from another repository" \
	"$([ -z "$(printf '%s' "$info" | jq -r '.url // empty')" ]; echo $?)"

echo ""
if [ "$failures" -eq 0 ]; then echo "ALL PASS"; exit 0; fi
echo "$failures CHECK(S) FAILED"; exit 1
