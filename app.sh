#!/bin/sh

# --------- CONFIGURATION ---------
LUCIBASE="http://127.0.0.1/cgi-bin/luci"
TMP_DIR="/tmp"
TMP_RESPONSE="${TMP_DIR}/api_response.json"

# List of Passwall2 apps that can be updated
AVAILABLE_APPS="xray sing-box v2ray hysteria naiveproxy tuic"

# --------- FUNCTIONS ---------
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

die() {
    log_message "ERROR: $1"
    exit 1
}

# Get LuCI token from local system
get_luci_token() {
    # Try to extract token from current LuCI session if available
    local token=$(uci get luci._token 2>/dev/null)
    
    # Fallback: get token from LuCI homepage
    if [ -z "$token" ]; then
        token=$(curl -s "$LUCIBASE" | grep -o 'token=[^"]*' | head -n1 | cut -d= -f2)
    fi
    
    if [ -z "$token" ]; then
        die "Failed to obtain LuCI token"
    fi
    
    echo "$token"
}

# Make API request function
make_api_request() {
    local endpoint="$1"
    local params="$2"
    local token=$(get_luci_token)
    local url="$LUCIBASE/admin/services/passwall2/$endpoint?token=$token&$params"
    
    curl -s "$url" > "$TMP_RESPONSE"
    
    if [ $? -ne 0 ]; then
        die "API request to $endpoint failed"
    fi
    
    # Check if response indicates success
    if grep -q '"success":true' "$TMP_RESPONSE" || ! grep -q '"success":false' "$TMP_RESPONSE"; then
        cat "$TMP_RESPONSE"
        return 0
    else
        log_message "API response: $(cat "$TMP_RESPONSE")"
        return 1
    fi
}

# --------- MAIN SCRIPT ---------
# Check if command is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <command> [appname]"
    echo "Commands:"
    echo "  update <appname>     - Update a specific app ($AVAILABLE_APPS)"
    echo "  update-all           - Update all available apps"
    echo "  status               - Get Passwall2 status"
    echo "  log [lines]          - Get recent logs (default: 50 lines)"
    echo "  restart              - Restart Passwall2 service"
    echo "  subscribe            - Update subscriptions"
    echo "  get-config           - Get current configuration"
    exit 1
fi

COMMAND="$1"
APPNAME="$2"
LINES="${3:-50}"  # Default to 50 lines for log command

case "$COMMAND" in
    update)
        if [ -z "$APPNAME" ]; then
            die "App name required for update. Available apps: $AVAILABLE_APPS"
        fi
        
        # Verify app is valid
        if ! echo "$AVAILABLE_APPS" | grep -qw "$APPNAME"; then
            die "Invalid app name. Available apps: $AVAILABLE_APPS"
        fi
        
        log_message "Getting download info for $APPNAME..."
        app_info=$(make_api_request "get_${APPNAME}_info")
        
        DLURL=$(echo "$app_info" | grep -o '"url":"[^"]*"' | head -n1 | cut -d'"' -f4)
        SIZE=$(echo "$app_info" | grep -o '"size":"[^"]*"' | head -n1 | cut -d'"' -f4)
        
        if [ -z "$DLURL" ] || [ -z "$SIZE" ]; then
            die "Could not get download info for $APPNAME"
        fi
        
        log_message "Triggering update for $APPNAME..."
        update_result=$(make_api_request "update_${APPNAME}" "url=$DLURL&size=$SIZE")
        log_message "Update triggered: $update_result"
        ;;

    update-all)
        log_message "Updating all available apps..."
        for app in $AVAILABLE_APPS; do
            log_message "Processing $app..."
            app_info=$(make_api_request "get_${app}_info")
            
            DLURL=$(echo "$app_info" | grep -o '"url":"[^"]*"' | head -n1 | cut -d'"' -f4)
            SIZE=$(echo "$app_info" | grep -o '"size":"[^"]*"' | head -n1 | cut -d'"' -f4)
            
            if [ -n "$DLURL" ] && [ -n "$SIZE" ]; then
                update_result=$(make_api_request "update_$app" "url=$DLURL&size=$SIZE")
                log_message "$app update: $update_result"
            else
                log_message "Skipping $app - no update available"
            fi
        done
        ;;

    status)
        log_message "Getting Passwall2 status..."
        status=$(make_api_request "status")
        echo "Status: $status"
        ;;

    log)
        log_message "Getting last $LINES lines of logs..."
        logs=$(make_api_request "get_log" "lines=$LINES")
        echo "Logs: $logs"
        ;;

    restart)
        log_message "Restarting Passwall2 service..."
        result=$(make_api_request "restart")
        log_message "Restart result: $result"
        ;;

    subscribe)
        log_message "Updating subscriptions..."
        result=$(make_api_request "subscribe")
        log_message "Subscription update result: $result"
        ;;

    get-config)
        log_message "Retrieving configuration..."
        config=$(make_api_request "get_config")
        echo "Configuration: $config"
        ;;

    *)
        die "Unknown command: $COMMAND"
        ;;
esac

log_message "Operation completed successfully"
rm -f "$TMP_RESPONSE"
