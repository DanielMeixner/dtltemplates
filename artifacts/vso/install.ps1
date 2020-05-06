[CmdletBinding()]
param(
    # .
    [string] $mail,

    # 
    [string] $resourcegroup = "no-rg",

    # 
    [string] $subscriptionid = "no-subscription-id",
    
    # 
    [string] $planname = "no-plan-name",

    # 
    [string] $user = "no-user",

    # Minimum PowerShell version required to execute this script.
    [SecureString] $password = "no-pw"

    
)


####### Give user logon as service permission
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

####  now the user should have "logon as svc permissions"




# Prepare reg file
# (Get-Content .\vso.reg) -replace '____OBJECTNAME____', (".\\"+$user) | Set-Content .\vso.reg
# (Get-Content .\vso.reg) -replace '____KEYNAME____', ("vso.$env:computername."+$user)| Set-Content .\vso.reg
# (Get-Content .\vso.reg) -replace '____DISPLAYNAME____', 'Visual Studio Online (installed via DTL)' | Set-Content .\vso.reg
# Get-Content .\vso.reg

# # register service
# reg import .\vso.reg

# show pw and user in plaintext
$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($password)
$decryptedpw = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)
Write-Host "Decrypted PW: " + $decryptedpw + " User:  " +$user
whoami


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
$runpath = $destination + "\vso.exe"


$authrelayurl = "https://prod-95.westeurope.logic.azure.com:443/workflows/23f06675f48646998a91d97a55a56235/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=50KJExnmWKyTiN5WwT1X8o6ekd7KAOZwqboO-VWdZig"
$guid = New-Guid
Write-Host "GUID" + $guid
$outfilename = ".\out" + $guid + ".txt"
Write-Host $outfilename

$args = " start -r " + $resourcegroup + " -s " + $subscriptionid + " --plan-name " + $planname +  " -n " + "DTL_"+ $env:computername +"_"+ $guid 

Write-Host "argslist: " + $args


### register for vso; vso start --service ...
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 


#$credential = New-Object System.Management.Automation.PSCredential $user, $password

Write-Host "USER" + $user
Write-Host "PW" + $password

Start-Process $runpath  -ArgumentList $args -RedirectStandardOutput $outfilename -WindowStyle Hidden -RedirectStandardInput .\input.txt #-Credential $credential
 
# dirty for now - later wait for file being created and filled.
Start-Sleep 5

$res = Get-Content $outfilename
 
Write-Host "res:"+$res
    
$params = @{    
    mail    = $mail + ''
    message = $res + ''
}
Invoke-WebRequest -Uri $authrelayurl -Method Post -Body ($params | ConvertTo-Json) -ContentType "application/json" -UseBasicParsing
Write-Host "sended"

Start-Sleep 120
### kill vso process ###
$proc=Get-Process vso
$proc.kill()
Write-Host "process killed"

##### register vso service

sc.exe create VSOService  binpath="c:\VSOnline\vso.exe vmagent -s -t" obj=".\$user" password=$decryptedpw start=auto

 