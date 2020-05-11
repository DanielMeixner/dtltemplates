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


### download vso installer
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



$guid = New-Guid
Write-Host "GUID" + $guid
$outfilename = ".\out" + $guid + ".txt"
Write-Host $outfilename

$vsoargs = " start -r " + $resourcegroup + " -s " + $subscriptionid + " --plan-name " + $planname +  " -n " + "DTL_"+ $env:computername +"_"+ $guid 

Write-Host "argslist: " + $vsoargs


### register for vso; vso start --service ...
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 


#$credential = New-Object System.Management.Automation.PSCredential $user, $password

Write-Host "USER" + $user
Write-Host "PW" + $password

### execute vso 
# Start-Process $runpath  -ArgumentList $vsoargs -RedirectStandardOutput $outfilename -WindowStyle Hidden -RedirectStandardInput .\input.txt #-Credential $credential

### psexec
# $psexecpath =".\PsExec.exe"
# $workdir = "C:\Users\$user\vso\"
# $psexecargs =" -w $workdir -u $user -p $decryptedpw -accepteula $runpath $vsoargs "
# if (!(Test-Path -path $workdir)) {New-Item $workdir -Type Directory}
# Write-Host $psexecpath -ArgumentList $psexecargs -RedirectStandardOutput $outfilename -WindowStyle Hidden -RedirectStandardInput .\input.txt 
# Start-Process $psexecpath -ArgumentList $psexecargs -RedirectStandardOutput $outfilename -WindowStyle Hidden -RedirectStandardInput .\input.txt 
 


$psexecOutputFile= "c:\vso_out_.txt"
### Start file watcher in background waiting for file. 
# Start-Process powershell -RedirectStandardOutput  "c:\watcherout.txt"  -ArgumentList ".\watcher.ps1 -mail $mail -filename $psexecOutputFile -user $user -decryptedpw $decryptedpw -ExecutionPolicy bypass"

Start-Process  powershell  -RedirectStandardOutput  "c:\watcherout.txt"  -ArgumentList "-ExecutionPolicy Bypass -File .\watcher.ps1 -mail $mail -filename $psexecOutputFile -user $user -decryptedpw $decryptedpw "

### Start PSExec in Forground and write to file
### vso will do the registration but not as service
### file watcher will wait for the registration to complete, create a service and kill the vso proc

.\psexec \\127.0.0.1 "-u" "$user" "-accepteula" "-p" "$decryptedpw" c:\Vsonline\vso.exe "start" "-k" > $psexecOutputFile

# ### wait for selfhosted file
# $selfhostedfilepath="C:\Windows\SysWOW64\config\systemprofile\.vsonline\selfHosted.json"

# while (!(Test-Path $selfhostedfilepath )) { Start-Sleep 10 }

# ### create copy of file
# $dtlfolder="C:\Users\$user\.dtl\"
# if (!(Test-Path -path $dtlfolder)) {New-Item $dtlfolder -Type Directory}
# Copy-Item -Path  $selfhostedfilepath $dtlfolder


# ### copy file back to user dir
# $vsofolder="C:\Users\$user\.vsonline\"
# if (!(Test-Path -path $vsofolder)) {New-Item $vsofolder -Type Directory}
# Copy-Item -Path  $dtlfolder"selfHosted.json" $vsofolder

# ### replace user
# $file= "C:\Users\$user\.vsonline\selfHosted.json"
# $regex = '("runAsUser)[^.]*'
# (Get-Content $file) -replace $regex, ('"runAsUser"' + ":" + '"'+".\\$user" + '",')  | Set-Content $file

# ### replace workpath
# New-Item "C:\\Users\\$user\\vso" -Type Directory
# $regexws = '("workspacePath)[^,]*'
# (Get-Content $file) -replace $regexws, ('"workspacePath"' + ":" + '"'+"C:\\Users\\$user\\vso" + '"')  | Set-Content $file

# Write-Host ".vsonline - modified"
# Get-Content $file
# # Write-Host "dtl - original file"
# # Get-Content $dtlfolder"selfHosted.json"

# ### create computername dir and copy file to it
# $computernamedir="C:\Users\$user.$env:computername\"
# New-Item $computernamedir -Type Directory
# Copy-Item -Path  $dtlfolder"selfHosted.json" $vsofolder







