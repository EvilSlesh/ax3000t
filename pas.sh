#!/bin/sh
# Passwall2 core updater (latest OpenWrt + Passwall2 only)

LUCIBASE="http://127.0.0.1/cgi-bin/luci"
USER="root"
PASS="123456789"
APPS="xray sing-box hysteria"

# login and grab sysauth cookie
COOKIE=$(curl -s -i -d "luci_username=$USER&luci_password=$PASS" $LUCIBASE/admin/passwall2 | \
         grep -i "Set-Cookie" | grep -o 'sysauth=[^;]*')

for app in $APPS; do
    INFO=$(curl -s --cookie "$COOKIE" "$LUCIBASE/admin/services/passwall2/get_${app}_info")
    URL=$(echo "$INFO" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
    SIZE=$(echo "$INFO" | grep -o '"size":"[^"]*"' | cut -d'"' -f4)

    if [ -n "$URL" ] && [ -n "$SIZE" ]; then
        echo "Updating $app..."
        RES=$(curl -s --cookie "$COOKIE" "$LUCIBASE/admin/services/passwall2/update_${app}?url=$URL&size=$SIZE")
        echo "$RES" | grep -q '"success":true' && echo "$app updated." || echo "$app failed."
    else
        echo "No update for $app."
    fi
done
