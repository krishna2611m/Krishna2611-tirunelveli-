﻿$BESClientresult = @()
$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #96C7FF;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@
    $servers = Get-Content -Path "C:\temp\Servers.csv"
    foreach ($server in $servers) {	
    If (Test-Connection -BufferSize 32 -Count 1 -computername $server -Quiet) {
try 
{
Get-Service BESClient -computername $server | Restart-Service -Verbose -WarningAction SilentlyContinue -ErrorAction Stop
$BESClientstatus = "BESClient Service Restarted Successfully"
}
catch
{
$BESClientstatus
}
}
Else {
$BESClientstatus = "BESClient Service Failed to Restart"
}
$BESClientresult += [PSCustomObject]@{
                        ServerName = $server
                        Status = $BESClientstatus
                        }
}
$body = $BESClientresult | Select ServerName,Status | ConvertTo-Html -Head $Header

Send-MailMessage -From "rxxxsystems@xxxx.com" -To " " -Subject "BESClient Status" -Body "$body" -BodyAsHtml -smtpServer smtprelay.messageprovider.com