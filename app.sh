#!/bin/sh
# Sing-box Auto-updater using Passwall2 API
# BusyBox-only: curl, sed, grep, awk, ubus
# Logs in to LuCI, checks Passwall2 Sing-box core, and updates if needed.

USER="${USER:-root}"
PASS="${PASS:-your_password}"
HOST="${HOST:-192.168.1.1}"

set -eu

TMPCOOK="$(mktemp)"
trap 'rm -f "$TMPCOOK"' EXIT

# 1) Acquire sysauth cookie
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

# 2) Fetch page containing CSRF token
TS="$(date +%s)000"
PAGE=$(curl -sk $COOKIE_ARG "http://$HOST/cgi-bin/luci/admin/services/passwall2?_=${TS}" || true)
[ -z "$PAGE" ] && PAGE=$(curl -sk $COOKIE_ARG "http://$HOST/cgi-bin/luci/admin/status/overview?_=${TS}" || true)

# 3) Extract CSRF token
CSRF=""
CSRF=$(printf '%s' "$PAGE" | sed -n "s/.*L\\.env\\.token=['\"]\\([0-9a-f]\\{32\\}\\)['\"].*/\1/p" | head -n1)
[ -z "$CSRF" ] && CSRF=$(printf '%s' "$PAGE" | sed -n "s/.*var[[:space:]]\\+token=['\"]\\([0-9a-f]\\{32\\}\\)['\"].*/\1/p" | head -n1)
[ -z "$CSRF" ] && CSRF=$(printf '%s' "$PAGE" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{32\}\)".*/\1/p' | head -n1)
[ -z "$CSRF" ] && { echo "ERROR: failed to extract CSRF token"; exit 1; }

printf 'LuCI CSRF token: %s\n' "$CSRF" >&2

# 4) Call check_sing-box API
CHECK=$(curl -sk $COOKIE_ARG \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'X-Requested-With: XMLHttpRequest' \
  "http://$HOST/cgi-bin/luci/admin/services/passwall2/check_sing-box?token=${CSRF}&arch=&_=${TS}" || true)

# 5) Extract values
HAS_UPDATE=$(printf '%s' "$CHECK" | sed -n 's/.*"has_update":[[:space:]]*\(true\|false\).*/\1/p' | head -n1)
URL=$(printf '%s' "$CHECK" | sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
URL=$(printf '%s' "$URL" | sed 's#\\/#/#g')
SIZE_BYTES=$(printf '%s' "$CHECK" | sed -n 's/.*"size":[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n1)

# 6) Decide and update
if [ "$HAS_UPDATE" = "true" ]; then
    SIZE_MB=$(awk "BEGIN {printf \"%.6f\", $SIZE_BYTES/1024/1024}")
    echo "Update available!"
    echo "Download URL: $URL"
    echo "Size (MB): $SIZE_MB"

    # Trigger Passwall2 Sing-box update
    curl -sk $COOKIE_ARG \
      -H "X-CSRF-Token: $CSRF" \
      "http://$HOST/cgi-bin/luci/admin/services/passwall2/update_sing-box?token=$CSRF&url=$URL&size=$SIZE_MB"

    echo "Update triggered."
else
    echo "No update needed. Sing-box core is up to date."
fi
