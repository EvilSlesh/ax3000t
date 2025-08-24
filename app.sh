#!/bin/sh

# --------- CONFIGURATION ---------
LUCIPASS="YOUR_LUCI_PASSWORD"
LUCIUSER="root"
LUCIBASE="http://127.0.0.1/cgi-bin/luci"
APPNAME="sing-box"
TMP_DIR="/tmp"
TMP_LOGIN="${TMP_DIR}/luci_login.json"
TMP_COOKIE="${TMP_DIR}/luci_cookie.txt"
TMP_INFO="${TMP_DIR}/passwall2_info.json"

# --------- FUNCTIONS ---------
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

cleanup() {
    rm -f "$TMP_LOGIN" "$TMP_COOKIE" "$TMP_INFO"
    log_message "Cleaned up temporary files"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# --------- STEP 1: Login to LuCI ---------
log_message "Logging in to LuCI interface..."
login_response=$(curl -s -c "$TMP_COOKIE" -X POST \
    -d "luci_username=$LUCIUSER&luci_password=$LUCIPASS" \
    "$LUCIBASE")

if [ $? -ne 0 ] || ! grep -q "token" "$TMP_COOKIE" 2>/dev/null; then
    # Try alternative token extraction from response body
    TOKEN=$(echo "$login_response" | grep -o 'token=[^"]*' | head -n1 | cut -d= -f2)
    
    if [ -z "$TOKEN" ]; then
        log_message "ERROR: Failed to authenticate with LuCI. Check credentials."
        exit 1
    fi
else
    # Extract token from cookie
    TOKEN=$(grep "token=" "$TMP_COOKIE" | head -n1 | sed 's/.*token=\([^;]*\).*/\1/')
fi

log_message "Successfully authenticated, token: $TOKEN"

# --------- STEP 2: Get App Info from Passwall2 API ---------
log_message "Fetching $APPNAME information from Passwall2 API..."
API_INFO_URL="$LUCIBASE/admin/services/passwall2/get_${APPNAME}_info"

curl -s -b "$TMP_COOKIE" \
    "$API_INFO_URL?token=$TOKEN" > "$TMP_INFO"

if [ $? -ne 0 ] || ! grep -q "url" "$TMP_INFO"; then
    log_message "ERROR: Failed to get $APPNAME info from Passwall2 API"
    exit 2
fi

# Extract URL and size from Passwall2 API response
DLURL=$(grep -o '"url":"[^"]*"' "$TMP_INFO" | head -n1 | cut -d'"' -f4)
SIZE=$(grep -o '"size":"[^"]*"' "$TMP_INFO" | head -n1 | cut -d'"' -f4)

if [ -z "$DLURL" ] || [ -z "$SIZE" ]; then
    log_message "ERROR: Could not extract download URL or size from API response"
    cat "$TMP_INFO"
    exit 3
fi

log_message "Found $APPNAME download URL: $DLURL"
log_message "File size: $SIZE"

# --------- STEP 3: Trigger Passwall2 Update ---------
log_message "Triggering $APPNAME update..."
API_UPDATE_URL="$LUCIBASE/admin/services/passwall2/update_${APPNAME}"

update_response=$(curl -s -b "$TMP_COOKIE" -X GET \
    "$API_UPDATE_URL?token=$TOKEN&url=$DLURL&size=$SIZE")

if [ $? -eq 0 ]; then
    log_message "Update successfully triggered!"
    log_message "Response: $update_response"
else
    log_message "ERROR: Failed to trigger update"
    exit 4
fi

log_message "Update process started in the background."
log_message "Check the Passwall2 Logs page for update progress."
