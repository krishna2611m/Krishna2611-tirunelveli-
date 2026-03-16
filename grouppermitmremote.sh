#!/bin/bash

# --- Config ---
NEW_GROUP="MSP-xxx-Linux-Server-Access@xxx.DMZ"
SERVER_LIST="/linuxadmin/scripts/pre-check/mspchange1"
SUMMARY_OUT="/linuxadmin/scripts/pre-check/Purestorage/realmd_permit_summary_$(date +'%Y%m%d_%H%M%S').txt"

# Default creds / SSH config
SSHCFG="/etc/ssh/custom/config"
SSHRSA="/etc/ssh/custom/id_rsa"

# --- Ensure we run as adminuser locally ---
if [[ "$(id -un)" != "adminuser" ]]; then
  exec sudo -n -u adminuser -- "$0" "$@"
fi

# Initialize summary file
echo "SSSD Permit Update Summary - $(date)" > "$SUMMARY_OUT"
echo "Target Group: $NEW_GROUP" >> "$SUMMARY_OUT"
echo "---------------------------------------------------------------" >> "$SUMMARY_OUT"

# Use FD 3 to prevent SSH from "eating" the server list
while IFS= read -u 3 -r server || [ -n "$server" ]; do
    [[ -z "$server" || "$server" =~ ^# ]] && continue

    echo "Processing $server..."

    # Remote Logic
    REMOTE_CMD=$(cat <<'EOF'
        FILE="/etc/sssd/sssd.conf"

        # 1. Check existence using sudo (in case directory is 700)
        if ! sudo test -f "$FILE"; then
            echo "ERROR: /etc/sssd/sssd.conf not found on this host"
            exit
        fi

        # 2. Extract the line using sudo and clean it
        # We search for the string anywhere on the line
        LINE_CONTENT=$(sudo grep "simple_allow_groups" "$FILE" | head -n 1 | tr -d '\r')

        if [ -z "$LINE_CONTENT" ]; then
            echo "ERROR: 'simple_allow_groups' string missing in file"
        elif echo "$LINE_CONTENT" | grep -q "$NEW_GROUP"; then
            echo "EXISTS: $LINE_CONTENT"
        else
            # Backup
            sudo cp "$FILE" "${FILE}.bak_$(date +%Y%m%d)"

            # 3. Append Group
            # Matches any line containing simple_allow_groups and appends a comma + new group
            sudo sed -i "/simple_allow_groups/ s/$/ , $NEW_GROUP/" "$FILE"

            # Cleanup formatting (remove triple commas, handle spacing)
            sudo sed -i 's/,,*/,/g; s/ ,/, /g; s/  */ /g' "$FILE"

            # Restart
            sudo systemctl restart sssd

            # Final verification
            FINAL=$(sudo grep "simple_allow_groups" "$FILE" | head -n 1 | tr -d '\r')
            echo "UPDATED: $FINAL"
        fi
EOF
)

    # SSH Execution
    # -n is critical here to allow the loop to continue to the next server
    RESULT=$(ssh -n -F "$SSHCFG" -i "$SSHRSA" \
             -o ConnectTimeout=10 \
             -o StrictHostKeyChecking=no \
             "$server" "export NEW_GROUP='$NEW_GROUP'; $REMOTE_CMD" 2>/dev/null)

    if [ $? -eq 0 ] && [[ -n "$RESULT" ]]; then
        # Pick up our specific status tags
        CLEAN_RESULT=$(echo "$RESULT" | grep -E "UPDATED:|EXISTS:|ERROR:" | tail -n 1)
        echo "SUCCESS: $server | $CLEAN_RESULT" >> "$SUMMARY_OUT"
    else
        echo "FAILED: $server | SSH connection error or timeout" >> "$SUMMARY_OUT"
    fi

done 3< "$SERVER_LIST"

echo "Task Complete. Summary: $SUMMARY_OUT"
