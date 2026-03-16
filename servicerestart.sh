#!/bin/bash

# --- Config ---
SERVICE_NAME="sssd.service"
SERVER_LIST="/linuxadmin/scripts/pre-check/mspchange1"
SUMMARY_OUT="/linuxadmin/scripts/pre-check/Purestorage/service_status_$(date +'%Y%m%d_%H%M%S').txt"

# Default creds / SSH config
SSHCFG="/etc/ssh/custom/config"
SSHRSA="/etc/ssh/custom/id_rsa"

# --- Ensure we run as adminuser locally ---
if [[ "$(id -un)" != "adminuser" ]]; then
  exec sudo -n -u adminuser -- "$0" "$@"
fi

# Initialize summary file
echo "Service Management Report: $SERVICE_NAME" > "$SUMMARY_OUT"
echo "Date: $(date)" >> "$SUMMARY_OUT"
echo "---------------------------------------------------------------" >> "$SUMMARY_OUT"

# Use FD 3 to prevent SSH from consuming the server list
while IFS= read -u 3 -r server || [ -n "$server" ]; do
    [[ -z "$server" || "$server" =~ ^# ]] && continue

    echo "Processing $server..."

    # Remote Logic: Restart and then grep for the status line
    REMOTE_CMD=$(cat <<EOF
        sudo systemctl restart $SERVICE_NAME
        if [ \$? -eq 0 ]; then
            # Capture the 'Active:' line from systemctl status
            STATUS=\$(sudo systemctl status $SERVICE_NAME | grep "Active:" | xargs)
            echo "SUCCESS | \$STATUS"
        else
            echo "FAILED | Could not restart service"
        fi
EOF
)

    # Execute via SSH
    RESULT=$(ssh -n -F "$SSHCFG" -i "$SSHRSA" -o ConnectTimeout=10 "$server" "$REMOTE_CMD" 2>/dev/null)

    if [[ -n "$RESULT" ]]; then
        echo "Server: $server | $RESULT" >> "$SUMMARY_OUT"
    else
        echo "Server: $server | FAILED: SSH Connection timeout or error" >> "$SUMMARY_OUT"
    fi

done 3< "$SERVER_LIST"

echo "Task Complete. Summary written to: $SUMMARY_OUT"
