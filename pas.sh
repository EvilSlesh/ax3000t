#!/bin/sh
# Minimal Passwall2 sing-box update checker

LUCIBASE="http://127.0.0.1/cgi-bin/luci"
USER="root"
PASS="123456789"

COOKIE=$(curl -s -i -d "luci_username=$USER&luci_password=$PASS" \
    $LUCIBASE/admin/passwall2 | grep -o 'sysauth=[^;]*')

# Step 1: trigger remote check
curl -s --cookie "$COOKIE" "$LUCIBASE/admin/services/passwall2/get_sing-box_info/check" >/dev/null

# Step 2: read info
INFO=$(curl -s --cookie "$COOKIE" "$LUCIBASE/admin/services/passwall2/get_sing-box_info")

REMOTE=$(echo "$INFO" | jsonfilter -e '@.remote_version' 2>/dev/null)
LOCAL=$(echo "$INFO" | jsonfilter -e '@.local_version' 2>/dev/null)
URL=$(echo "$INFO" | jsonfilter -e '@.url' 2>/dev/null)
SIZE=$(echo "$INFO" | jsonfilter -e '@.size' 2>/dev/null)

if [ -n "$REMOTE" ] && [ "$REMOTE" != "$LOCAL" ]; then
    echo "Updating sing-box from $LOCAL to $REMOTE..."
    RES=$(curl -s --cookie "$COOKIE" "$LUCIBASE/admin/services/passwall2/update_sing-box?url=$URL&size=$SIZE")
    echo "$RES" | jsonfilter -e '@.msg'
else
    echo "No update for sing-box."
fi
