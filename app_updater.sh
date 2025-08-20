#!/bin/sh

# Passwall2-style Manual App Updater
APP_NAME="sing-box" # Change to 'xray', 'v2ray', etc. if needed

# Detect Architecture
APP_ARCH=$(uci get passwall2.@global[0].arch 2>/dev/null)
if [ -z "$APP_ARCH" ]; then
    APP_ARCH=$(opkg print-architecture | awk '{print $2}' | head -1)
fi
BASE_URL="https://master.dl.sourceforge.net/project/openwrt-passwall-bin/packages/$APP_ARCH"

echo "> Architecture: $APP_ARCH"
echo "> Target: $APP_NAME"

# Check Versions
SERVER_VERSION=$(curl -fsL "$BASE_URL/$APP_NAME/version" | head -n1)
CURRENT_VERSION=$($(which $APP_NAME) version 2>/dev/null | head -n1 | awk '{print $2}' || echo "0")
echo "> Server: $SERVER_VERSION"
echo "> Current: ${CURRENT_VERSION:-Not Found}"

if [ "$SERVER_VERSION" = "$CURRENT_VERSION" ]; then
    echo "✓ Already up-to-date." && exit 0
fi
echo "! Update found."

# Setup Temp Directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || exit 1

# Download and Verify
echo "> Downloading from $BASE_URL..."
curl -fsL -o "./$APP_NAME.tar.gz" "$BASE_URL/$APP_NAME/$APP_NAME-$SERVER_VERSION.tar.gz"
curl -fsL -o "./sha256sums" "$BASE_URL/$APP_NAME/sha256sums"

if ! sha256sum -c --ignore-missing sha256sums; then
    echo "! Checksum mismatch. Aborting." >&2
    rm -rf "$TMP_DIR"
    exit 1
fi
echo "✓ Checksum valid."

# Install
echo "> Installing..."
tar -xzf "$APP_NAME.tar.gz"
/etc/init.d/passwall2 stop
/etc/init.d/"$APP_NAME" stop 2>/dev/null
mv "$(which $APP_NAME)" "$(which $APP_NAME)".bak 2>/dev/null
install -m 755 "./$APP_NAME" "/usr/bin/"
/etc/init.d/"$APP_NAME" start 2>/dev/null
/etc/init.d/passwall2 start

# Final Check
echo "✓ Done. Final version: $($(which $APP_NAME) version | head -n1)"
rm -rf "$TMP_DIR"
