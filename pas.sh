#!/bin/sh
# Passwall2 core updater (OpenWrt + Passwall2 latest only)

LUCIBASE="http://127.0.0.1/cgi-bin/luci"
USER="root"
PASS="123456789"
APPS="xray sing-box hysteria"

# login and grab cookie
COOKIE=$(curl -s -i -d "luci_username=$USER&luci_password=$PASS" $LUCIBASE/admin/passwall2 \
         | grep -i "Set-Cookie" | grep -o 'sysauth=[^;]*')

for app in $APPS; do
    INFO=$(curl -s --cookie "$COOKIE" "$LUCIBASE/admin/services/passwall2/get_${app}_info?check=1")

    REMOTE=$(echo "$INFO" | jsonfilter -e '@.remote_version')
    LOCAL=$(echo "$INFO" | jsonfilter -e '@.local_version')
    URL=$(echo "$INFO" | jsonfilter -e '@.url')
    SIZE=$(echo "$INFO" | jsonfilter -e '@.size')

    if [ -n "$REMOTE" ] && [ "$REMOTE" != "$LOCAL" ]; then
        echo "Updating $app from $LOCAL to $REMOTE..."
        RES=$(curl -s --cookie "$COOKIE" "$LUCIBASE/admin/services/passwall2/update_${app}?url=$URL&size=$SIZE")
        echo "$RES" | jsonfilter -e '@.msg'
    else
        echo "$app is already latest ($LOCAL)."
    fi
done
