#!/bin/bash

RED='[0;31m'
NC='[0m'
GRN='[0;32m'
SSHCFG=/etc/ssh/custom/config
SSHRSA=/etc/ssh/custom/id_rsa
MESSAGE_BODY="Please find the attached report."

if [ "$(whoami)" != "adminuser" ]; then
    exec sudo -u adminuser "$0" "$@"
fi

# Path to server list
server_list="/linuxadmin/scripts/pre-check/mspchange1"

# Output CSV file path
output_file="/linuxadmin/scripts/pre-check/diskreport/agent_disk_usage_report_$(date +%F).csv"

# Email recipient
email_recipient="Krishna.murthy@xxx.com,xxx@.com"

# Header for CSV
echo "Server,Splunk Usage,Tanium Usage,SentinelOne Usage,Qualys Usage" > "$output_file"

# Loop through each server
while IFS= read -r server; do
    echo -e "${GRN}Checking $server...${NC}"

    # Run SSH command and capture disk usage
    result=$(ssh -q -o ConnectTimeout=10 -o StrictHostKeyChecking=no -F "$SSHCFG" -i "$SSHRSA" "adminuser@$server" 'bash -s' <<'EOF'
        splunk=$(sudo du -sh /opt/splunk* 2>/dev/null | awk '{print $1}' | paste -sd ";" -)
        tanium=$(sudo du -sh /opt/Tanium/TaniumClient 2>/dev/null | awk '{print $1}')
        sentinel=$(sudo du -sh /opt/sentinelone /opt/s1-agent 2>/dev/null | awk '{print $1}' | paste -sd ";" -)
        qualys=$(sudo du -sh /etc/qualys 2>/dev/null | awk '{print $1}')
        echo "$splunk|$tanium|$sentinel|$qualys"
EOF
    )

    # Parse result and write to CSV
    IFS='|' read -r splunk_usage tanium_usage sentinel_usage qualys_usage <<< "$result"
    echo "$server,$splunk_usage,$tanium_usage,$sentinel_usage,$qualys_usage" >> "$output_file"

done < "$server_list"

# Send the report via email
echo "$MESSAGE_BODY" | mail -s "Agent Disk Usage Report - $(date +%F)" -r "gtcloudlinuxsupport@manpowergroup.com" -a "$output_file" "$email_recipient"

# Notify completion
echo -e "${GRN}Report generated and emailed to $email_recipient: $output_file${NC}"

