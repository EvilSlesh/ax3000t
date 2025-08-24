#!/bin/sh
# Passwall2 core updater (OpenWrt latest only)

LUCIBASE="http://127.0.0.1/cgi-bin/luci"
USER="root"
PASS="123456789"
APPS="xray sing-box hysteria"

# login and grab cookie
COOKIE=$(curl -s -i -d "luci_username=$USER&luci_password=$PASS" $LUCIBASE/admin/passwall2 \
    | grep -o 'sysauth=[^;]*')

for app in $APPS; do
    INFO=$(curl -s --cookie "$COOKIE" "$LUCIBASE/admin/services/passwall2/get_${app}_info?check=1")

    # Debug step: if INFO is not JSON, show it
    echo "$INFO" | grep -q '^{'
    if [ $? -ne 0 ]; then
        echo "Error: $app did not return JSON. Got:"
        echo "$INFO"
        continue
    fi

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
