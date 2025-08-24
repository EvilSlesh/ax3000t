#!/bin/sh
# Passwall2 core updater (latest OpenWrt + Passwall2 only)

LUCIBASE="http://127.0.0.1/cgi-bin/luci"
USER="root"
PASS="123456789"
APPS="xray sing-box hysteria"

# login and grab sysauth cookie
COOKIE=$(curl -s -i -d "luci_username=$USER&luci_password=$PASS" \
    $LUCIBASE/admin/passwall2 | grep -o 'sysauth=[^;]*')

for app in $APPS; do
    INFO=$(curl -s --cookie "$COOKIE" "$LUCIBASE/admin/services/passwall2/get_${app}_info/check")

    REMOTE=$(echo "$INFO" | jsonfilter -e '@.remote_version' 2>/dev/null)
    LOCAL=$(echo "$INFO" | jsonfilter -e '@.local_version' 2>/dev/null)
    URL=$(echo "$INFO" | jsonfilter -e '@.url' 2>/dev/null)
    SIZE=$(echo "$INFO" | jsonfilter -e '@.size' 2>/dev/null)

    if [ -n "$REMOTE" ] && [ "$REMOTE" != "$LOCAL" ]; then
        echo "Updating $app from $LOCAL to $REMOTE..."
        RES=$(curl -s --cookie "$COOKIE" "$LUCIBASE/admin/services/passwall2/update_${app}?url=$URL&size=$SIZE")
        echo "$RES" | jsonfilter -e '@.msg'
    else
        echo "No update for $app."
    fi
done
