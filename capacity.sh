#!/bin/sh
MESSAGE="/tmp/xe-capacity.out"
MESSAGE2="/tmp/xe-capacity-1.csv"
echo "Runtime, XECluster, XEClusterNodes, CPUCores, SystemMemory, _Filesystem_Size, ActiveXESites, ReservedOSMemory, ConfiguredTomcatsMemory,
               ConfiguredApacheMemory, ApacheConnections, AvailableMemory, AvailableSysapDisk, Availablevarlogdisk" > $MESSAGE2
for server in `more /opt/scripts/servers-disk-usage.txt`
do
output=`ssh $server check_xe_capacity | tail -n +2 | sed s/%//g | awk '{ if($1 > 80) print $0;}'`
echo "$server $output" >> $MESSAGE
done
cat $MESSAGE | column -n | while read output;
do
Run_Time=$(echoawk '{print $1}')
XE_Cluster=$(echo $output awk '{print $2}')
XE_Cluster_Nodes=$(echo $output | awk '{print $3}')
CPU_Cores=$(echo $output | awk '{print $4}')
System_Memory=$(echo $output | awk '{print $5}')
/sysap_Filesystem_Size=$(echo $output | awk '{print $6}')
/usr_Filesystem_Size=$(echo $output | awk '{print $7}')
/var_Filesystem_Size=$(echo $output | awk '{print $8}')
/var_log_Filesystem_Size=$(echo $output | awk '{print $9}')
Number_Active_XE_Sites=$(echo $output | awk '{print $10}')
Reserved_OS_Memory=$(echo $output | awk '{print $11}')
Configured_Tomcats_Memory=$(echo $output | awk '{print $12}')
Configured_Apache_Memory=$(echo $output | awk '{print $13}')
Available_Apache_Connections=$(echo $output | awk '{print $14}')
Available_Memory=$(echo $output | awk '{print $15}')
Available_Disk_on_sysap=$(echo $output | awk '{print $16}')
Available_Disk_on_var_log=$(echo $output | awk '{print $17}')
echo "Runtime, XECluster, XEClusterNodes, CPUCores, SystemMemory, /sysap, /usr, /var, /varlog, ActiveXESites, ReservedOSMemory, ConfiguredTomcatsMemory,
               ConfiguredApacheMemory, ApacheConnections, AvailableMemory, AvailableSysapDisk, Availablevarlogdisk" >> $MESSAGE2
done

echo "XE Capacity Report for `date +"%B %Y"`" | mailx -s "XE Capacity Report on `date`" -a /tmp/xe-capacity-1.csv ryyyyyyyyy@xxx.com
fi
rm $MESSAGE
rm $MESSAGE2
