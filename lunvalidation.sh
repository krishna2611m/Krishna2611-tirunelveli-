#!/bin/bash

# --- Config ---
SERVER_LIST="/linuxadmin/scripts/pre-check/mspchange1"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
OUTPUT="/linuxadmin/scripts/pre-check/Purestorage/migration_report_$TIMESTAMP.html"
# Recipient list
email_recipient="Krishna.murthy@xxx.com,hariharan.t@xxx.com,anuraj.karumat@xxx.com"

# Colors for terminal output
GRN='\033[0;32m'
NC='\033[0m'

# Default creds / SSH config
SSHCFG="/etc/ssh/custom/config"
SSHRSA="/etc/ssh/custom/id_rsa"

# Counters for Summary Chart
total_count=0
success_count=0
fail_count=0

# --- Ensure we run as adminuser locally ---
if [[ "$(id -un)" != "adminuser" ]]; then
  exec sudo -n -u adminuser -- "$0" "$@"
fi

# 1. Process Servers
table_rows=""

while IFS= read -u 3 -r server || [ -n "$server" ]; do
    [[ -z "$server" || "$server" =~ ^# ]] && continue
    ((total_count++))
    echo "Fetching storage data from $server..."

    REMOTE_CMD=$(cat <<'EOF'
        # 1. Service & Multipath Health
        MP_RUNNING=$(systemctl is-active multipathd)
        HEALTH_ERR=$(sudo multipath -ll | grep -Ei "failed|faulty|shaky|offline")
        HEALTH_STATUS=$([ -z "$HEALTH_ERR" ] && echo "OK" || echo "CRITICAL")

        # 2. ALL Volume Groups on the Server (Name and Size)
        ALL_VGS=$(sudo vgs -o vg_name,vg_size --units g --noheadings | awk '{print $1 " (" $2 ")"}' | xargs -d '\n' echo "<br>" || echo "No VGs found")

        # 3. Pure LUN Info (Size & WWID)
        PURE_INFO=$(sudo multipath -ll | grep -i "PURE" -A 1 | awk '/size=/ {s=$1} /PURE/ {w=$2; gsub(/[()]/,"",w); print s " (WWID:" w ")"}')
        [ -z "$PURE_INFO" ] && PURE_INFO="Not Found"

        # 4. Pure LVM Mapping
        PURE_LVM=$(sudo pvs -o pv_name,vg_name --noheadings | grep "/dev/mapper/" | awk '{print $1 " -> " $2}' | xargs -d '\n' echo "<br>" || echo "No Mapper PVs")

        # 5. FSTAB Filter (Excluding rootvg, starting with /dev/)
        FSTAB_FILTERED=$(grep -v "rootvg" /etc/fstab | grep "^/dev/" | awk '{print $1 " [" $2 "]"}' | xargs -d '\n' echo "<br>" || echo "No matching entries")

        echo "$(hostname)|$MP_RUNNING|$ALL_VGS|$PURE_INFO|$PURE_LVM|$FSTAB_FILTERED|$HEALTH_STATUS"
EOF
)

    RAW_DATA=$(ssh -n -F "$SSHCFG" -i "$SSHRSA" -o ConnectTimeout=12 "$server" "$REMOTE_CMD" 2>/dev/null)

    if [ $? -eq 0 ] && [[ -n "$RAW_DATA" ]]; then
        IFS='|' read -r r_host r_mp r_vgs r_pure r_lvm r_fstab r_health <<< "$RAW_DATA"
        [[ "$r_mp" == "active" && "$r_health" == "OK" ]] && ((success_count++)) || ((fail_count++))

        mp_class=$([[ "$r_mp" == "active" ]] && echo "status-ok" || echo "status-crit")
        health_class=$([[ "$r_health" == "OK" ]] && echo "status-ok" || echo "status-crit")

        table_rows+="<tr><td><b>$r_host</b></td><td class='$mp_class'>$r_mp</td><td>$r_vgs</td><td>$r_pure</td><td>$r_lvm</td><td>$r_fstab</td><td class='$health_class'>$r_health</td></tr>"
    else
        ((fail_count++))
        table_rows+="<tr><td>$server</td><td colspan='6' class='status-crit'>CONNECTION FAILED</td></tr>"
    fi
done 3< "$SERVER_LIST"

# 2. Build HTML Output
cat <<EOF > "$OUTPUT"
<html>
<head>
<style>
    body { font-family: 'Segoe UI', Arial, sans-serif; padding: 20px; }
    .summary-box { margin-bottom: 25px; }
    .card { padding: 15px; border-radius: 8px; color: white; display: inline-block; width: 30%; text-align: center; margin-right: 10px; }
    .total { background-color: #004a99; } .success { background-color: #28a745; } .failure { background-color: #dc3545; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th { background-color: #004a99; color: white; padding: 10px; text-align: left; font-size: 13px; }
    td { border: 1px solid #ddd; padding: 8px; vertical-align: top; font-size: 11px; }
    tr:nth-child(even) { background-color: #f9f9f9; }
    .status-ok { color: #28a745; font-weight: bold; } .status-crit { color: #dc3545; font-weight: bold; }
</style>
</head>
<body>
    <h2>Migration Report: SAN & LVM Data Volume Validation</h2>
    <div class="summary-box">
        <div class="card total"><h3>$total_count</h3><p>Servers Checked</p></div>
        <div class="card success"><h3>$success_count</h3><p>Healthy / Ready</p></div>
        <div class="card failure"><h3>$fail_count</h3><p>Action Required</p></div>
    </div>
    <table>
        <tr>
            <th>Hostname</th>
            <th>Multipath</th>
            <th>All VGs (Size)</th>
            <th>Pure LUN (WWID)</th>
            <th>PV Mapping</th>
            <th>FSTAB (Data Disks)</th>
            <th>Health</th>
        </tr>
        $table_rows
    </table>
</body>
</html>
EOF

# 3. Robust Email Dispatch
# Using direct sendmail to ensure HTML headers are handled correctly by the relay
/usr/sbin/sendmail -t <<EOF
To: $email_recipient
Subject: MIGRATION REPORT: Pure Storage LUN & LVM Validation ($TIMESTAMP)
From: gtcloudlinuxsupport@manpowergroup.com
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8

$(cat "$OUTPUT")
EOF

echo -e "${GRN}MIGRATION REPORT: HTML report sent to $email_recipient.${NC}"
