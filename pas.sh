#!/bin/sh
# Passwall2 core updater (latest OpenWrt + Passwall2 only)

LUCIBASE="http://192.168.1.1/cgi-bin/luci"
APPS="xray sing-box hysteria"
AUTH="root:123456789"

for app in $APPS; do
    INFO=$(curl -s -u $AUTH "$LUCIBASE/admin/services/passwall2/get_${app}_info")
    URL=$(echo "$INFO" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
    SIZE=$(echo "$INFO" | grep -o '"size":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$URL" ] && [ -n "$SIZE" ]; then
        echo "Updating $app..."
        RES=$(curl -s -u $AUTH "$LUCIBASE/admin/services/passwall2/update_${app}?url=$URL&size=$SIZE")
        echo "$RES" | grep -q '"success":true' && echo "$app updated." || echo "$app failed."
    else
        echo "No update for $app."
    fi
done
