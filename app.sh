# --------- CONFIGURATION ---------
LUCIPASS="123456789"
LUCIUSER="root" # Usually 'root' for OpenWrt
LUCIBASE="http://127.0.0.1/cgi-bin/luci"
APPNAME="sing-box"
ARCH="arm64"   # Change to "armv7" if your device is not aarch64/arm64
TMP_LOGIN='/tmp/luci_login.json'
TMP_COOKIE='/tmp/luci_cookie.txt'
TMP_TOKEN='/tmp/luci_token.txt'
TMP_SINGBOX='/tmp/sing-box-release.json'

# --------- STEP 1: LOGIN and get SESSION TOKEN ---------
curl -s -c $TMP_COOKIE -X POST -d "luci_username=$LUCIUSER&luci_password=$LUCIPASS" \
  "$LUCIBASE" > $TMP_LOGIN

TOKEN=$(grep "token=" $TMP_COOKIE | head -n 1 | sed 's/.*token=\([^;]*\).*/\1/')
if [ -z "$TOKEN" ]; then
  # Try extracting from login reply (LuCI 23+)
  TOKEN=$(cat $TMP_LOGIN | grep -oP 'token=[a-zA-Z0-9]+' | head -n1 | cut -d= -f2)
fi

if [ -z "$TOKEN" ]; then
  echo "Failed to obtain LuCI token. Check your credentials."
  exit 1
fi

echo "LuCI token: $TOKEN"

# --------- STEP 2: GET Latest sing-box ARM Release URL ---------
curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" > $TMP_SINGBOX

# Find ARM asset URL
DLURL=$(cat $TMP_SINGBOX | grep -E 'browser_download_url.*linux-arm64' | grep -v '.tar.gz' | grep -o 'https[^"]*' | head -n1)
SIZE=$(cat $TMP_SINGBOX | grep -A8 "$DLURL" | grep '"size":' | grep -o '[0-9]\+' | head -n1)

if [ -z "$DLURL" ]; then
  echo "Could not find sing-box ARM release URL. Check the release format."
  exit 2
fi
echo "sing-box release: $DLURL (Size: $SIZE)"

# --------- STEP 3: Trigger Passwall2 App Update API ---------
APIURL="$LUCIBASE/admin/services/passwall2/update_${APPNAME}"

curl -s -b $TMP_COOKIE -X GET \
  "$APIURL?token=$TOKEN&url=$DLURL&size=$((SIZE/1024))"

echo "Update request sent. Check the Passwall2 App Update page for status."

# --------- CLEANUP ---------
rm -f $TMP_LOGIN $TMP_COOKIE $TMP_TOKEN $TMP_SINGBOX
