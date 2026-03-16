#!/bin/bash

# Colors
RED='\033[0;31m'
NC='\033[0m'
GRN='\033[0;32m'

SSHCFG=/etc/ssh/custom/config
SSHRSA=/etc/ssh/custom/id_rsa
MESSAGE_BODY="Please find the attached report."

if [ "$(whoami)" != "adminuser" ]; then
    exec sudo -u adminuser "$0" "$@"
fi

# Path to server list
server_list="/linuxadmin/scripts/pre-check/mspchange1"

# HTML output file
OUTPUT="/linuxadmin/scripts/pre-check/diskreport/disk_space_report.html"

# Email recipient
email_recipient="Krishna.murthy@xxx.com,hariharan.t@xxx.com"
SUBJECT="Disk Space Report Non Prod Linux Servers"
MAIL_CMD="/usr/bin/mail"

# Start HTML
cat <<EOF > $OUTPUT
<html>
<head>
<title>Disk Space Report</title>
<style>
body {font-family: Calibri, sans-serif;}
h2 {color: #333;}
table {border-collapse: collapse; width: 100%; margin-bottom: 20px;}
th, td {border: 1px solid #ddd; padding: 8px; text-align: left;}
th {background-color: #4CAF50; color: white;}
tr:nth-child(even) {background-color: #f2f2f2;}
</style>
</head>
<body>
<h2>Disk Space Report</h2>
EOF

# Read servers from file
servers=$(cat "$server_list")

for HOST in $servers; do
    echo "Collecting data from $HOST..."

    echo "<h3>Server: $HOST</h3>" >> $OUTPUT

    # Disk usage table
    echo "<h4>Filesystem Usage (df -hT)</h4><table><tr><th>Filesystem</th><th>Type</th><th>Size</th><th>Used</th><th>Avail</th><th>Use%</th><th>Mounted on</th></tr>" >> $OUTPUT
    ssh -q -o ConnectTimeout=10 -o StrictHostKeyChecking=no -F "$SSHCFG" -i "$SSHRSA" "adminuser@$HOST" \
    df -hT --exclude-type=tmpfs --exclude-type=devtmpfs | awk 'NR>1 && int($6) > 80 {print "<tr><td>"$1"</td><td>"$2"</td><td>"$3"</td><td>"$4"</td><td>"$5"</td><td>"$6"</td><td>"$7"</td></tr>"}' >> $OUTPUT
        echo "</table>" >> $OUTPUT
done

# End HTML
cat <<EOF >> $OUTPUT
</body>
</html>
EOF

# Send email with HTML content
echo "$MESSAGE_BODY" | mail -a "$OUTPUT" -s "Server Disk Usage Report - $(date +%F)" -r "gtcloudlinuxsupport@manpowergroup.com" "$email_recipient"

echo -e "${GRN}Disk Space Report: Report generated and emailed to $email_recipient: $OUTPUT${NC}"
