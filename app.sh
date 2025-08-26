#!/bin/sh
# BusyBox-only: curl, sed, grep, ubus
# This script logs in, gets CSRF, calls check_sing-box and extracts:
#   - has_update (true/false)
#   - browser_download_url (unescaped)
#   - size (bytes)
#
# Edit USER/PASS/HOST or export them before running.

USER="${USER:-root}"
PASS="${PASS:-your_password}"
HOST="${HOST:-192.168.1.1}"

set -eu

TMPCOOK="$(mktemp)"
trap 'rm -f "$TMPCOOK"' EXIT

# 1) Acquire a sysauth cookie
if [ -n "$PASS" ]; then
  curl -sk -c "$TMPCOOK" \
    -d "luci_username=$USER" -d "luci_password=$PASS" \
    -L "http://$HOST/cgi-bin/luci/" >/dev/null 2>&1 || true
  COOKIE_ARG="-b $TMPCOOK"
else
  UBUS=$(ubus call session create '{"timeout":300}' 2>/dev/null | sed -n 's/.*"ubus_rpc_session":"\([0-9a-f]\{32\}\)".*/\1/p')
  if [ -z "$UBUS" ]; then
    echo "ERROR: could not create ubus session; set a root password or provide PASS." >&2
    exit 1
  fi
  COOKIE_ARG="-b sysauth=$UBUS"
fi

# 2) Fetch page that contains CSRF token
TS="$(date +%s)000"
PAGE=$(curl -sk $COOKIE_ARG "http://$HOST/cgi-bin/luci/admin/services/passwall2?_=${TS}" || true)
if [ -z "$PAGE" ]; then
  PAGE=$(curl -sk $COOKIE_ARG "http://$HOST/cgi-bin/luci/admin/status/overview?_=${TS}" || true)
fi

# 3) Extract CSRF token
CSRF=""
CSRF=$(printf '%s' "$PAGE" | sed -n "s/.*L\\.env\\.token=['\"]\\([0-9a-f]\\{32\\}\\)['\"].*/\\1/p" | head -n1)
[ -z "$CSRF" ] && CSRF=$(printf '%s' "$PAGE" | sed -n "s/.*var[[:space:]]\\+token=['\"]\\([0-9a-f]\\{32\\}\\)['\"].*/\\1/p" | head -n1)
[ -z "$CSRF" ] && CSRF=$(printf '%s' "$PAGE" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{32\}\)".*/\1/p' | head -n1)

if [ -z "$CSRF" ]; then
  echo "ERROR: failed to extract LuCI CSRF token. Showing first 80 chars of page for debug:" >&2
  printf '%s\n' "$PAGE" | sed -n '1,8p' >&2
  exit 1
fi

printf 'LuCI CSRF token: %s\n' "$CSRF" >&2

# 4) Call check_sing-box (expect JSON)
CHECK=$(curl -sk $COOKIE_ARG \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'X-Requested-With: XMLHttpRequest' \
  "http://$HOST/cgi-bin/luci/admin/services/passwall2/check_sing-box?token=${CSRF}&arch=&_=${TS}" || true)

# 5) Extract the three fields using grep+sed (robust-ish, BusyBox friendly)
HAS_UPDATE=$(printf '%s' "$CHECK" | sed -n 's/.*"has_update":[[:space:]]*\(true\|false\).*/\1/p' | head -n1)
URL=$(printf '%s' "$CHECK" | sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
# unescape \/ -> /
URL=$(printf '%s' "$URL" | sed 's#\\/#/#g')
SIZE=$(printf '%s' "$CHECK" | sed -n 's/.*"size":[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n1)

# Basic validation and output
if [ -z "$HAS_UPDATE" ]; then
  echo "ERROR: could not find has_update in response. Here's first 120 chars of response for debugging:" >&2
  printf '%s\n' "$CHECK" | sed -n '1,12p' >&2
  exit 1
fi

printf 'has_update: %s\n' "$HAS_UPDATE"
printf 'browser_download_url: %s\n' "$URL"
printf 'size: %s\n' "$SIZE"
