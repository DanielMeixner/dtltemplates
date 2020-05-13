[CmdletBinding()]
param(
    # Email Address of user. Will be used to send authentication code to
    [string] $mail,

    # Resource group in Azure which holds the VS Codespaces plan
    [string] $resourcegroup = "no-rg",

    # Azure subscription Id
    [string] $subscriptionid = "no-subscription-id",
    
    # VS Codespaces plan name
    [string] $planname = "no-plan-name",

    # Username of user on machine, e.g daniel
    [string] $user = "no-user",

    # Password of user on machine
    [SecureString] $password = "no-pw"    
)
# this is the url of the app forwarding the auth code to the mail address
$authrelayurl = "https://prod-95.westeurope.logic.azure.com:443/workflows/23f06675f48646998a91d97a55a56235/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=50KJExnmWKyTiN5WwT1X8o6ekd7KAOZwqboO-VWdZig"

### Give user logon as service permission
Write-Host "Giving logonAsService permissions to user..."
$filter='name="'+$user+'"'
$filter
$res=Get-WmiObject win32_useraccount -Filter $filter | select sid

$AccountSid=$res.sid
$AccountSid

$ExportFile = 'c:\CurrentConfig.inf'
$SecDb = 'c:\secedt.sdb'
$ImportFile = 'c:\NewConfig.inf'

#Export the current configuration
secedit /export /cfg $ExportFile

#Find the current list of SIDs having already this right
$CurrentServiceLogonRight = Get-Content -Path $ExportFile |
    Where-Object -FilterScript {$PSItem -match 'SeServiceLogonRight'}

#Create a new configuration file and add the new SID
$FileContent = @'
[Unicode]
Unicode=yes
[System Access]
[Event Audit]
[Registry Values]
[Version]
signature="$CHICAGO$"
Revision=1
[Profile Description]
Description=GrantLogOnAsAService security template
[Privilege Rights]
SeServiceLogonRight = {0},*{1}
'@ -f $CurrentServiceLogonRight, $AccountSid

Set-Content -Path $ImportFile -Value $FileContent

#Import the new configuration 
secedit /import /db $SecDb /cfg $ImportFile
secedit /configure /db $SecDb

###  now the user should have "logon as svc permissions"


# convert pw to plaintext to pass it to watcher
Write-Host "Converting pw ..."
$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($password)
$decryptedpw = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

### download vso installer
Write-Host "Downloading installer ..."
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

Import-Module -Name "Microsoft.PowerShell.Archive"
$source = "https://vsoagentdownloads.blob.core.windows.net/vsoagent/VSOAgent_win_3633968.zip"
$webClient = New-Object System.Net.WebClient
$firstLetters = (New-Guid).ToString().SubString(0, 4)
$tempdestination = Join-Path -Path $env:TEMP  -ChildPath ("\vsoDownload" + $firstLetters + ".zip")
$WebClient.DownloadFile($source, $tempdestination)
$destination = Join-Path -Path $env:SystemDrive -ChildPath "VSOnline"
Expand-Archive -Path $tempdestination -Destination $destination -Force
Write-Host "Installed VSO to:" $destination
Write-Host "Run vso start to create your environment!"

$vsoexepath = $destination + "\vso.exe"


# guid will be used to identify env
$guid = New-Guid
Write-Host "Generated guid: $guid" 


### register for vso; 
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force  

$psexecOutputFile= "c:\vso_out_$guid.txt"
### Start file watcher in background waiting for file. 
Start-Process  powershell  -RedirectStandardOutput  "c:\watcher_out_$guid.txt"  -ArgumentList "-ExecutionPolicy Bypass -File .\watcher.ps1 -mail $mail -filename $psexecOutputFile -user $user -decryptedpw $decryptedpw -authrelayurl $authrelayurl"

### download PSExec
$pstoolszippath=".\PSTools.zip"
Invoke-WebRequest https://download.sysinternals.com/files/PSTools.zip -OutFile $pstoolszippath
Expand-Archive -Path $pstoolszippath -DestinationPath .


### Start PSExec in Forground and write output to file.
### -k makes sure that no questions will be asked
### vso will do the registration but will be running as process not as service-
### File watcher will wait for the registration to complete, create a service and kill the vso proc.
$machinename= "DTL_$env:computername_$guid"
.\psexec \\127.0.0.1 "-u" "$user" "-accepteula" "-p" "$decryptedpw" $vsoexepath "start" "-k" "--plan-id" "/subscriptions/$subscriptionid/resourceGroups/$resourcegroup/providers/Microsoft.VSOnline/plans/$planname"   "-n" $machinename  > $psexecOutputFile









