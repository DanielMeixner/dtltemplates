[CmdletBinding()]
param(
    # .
    [string] $mail,

    # 
    [string] $decryptedpw = "no-pw",

    # 
    [string] $user = "no-user",
    
    [string] $filename
)

Write-Host "Start watcher for file $filename" 
$authrelayurl = "https://prod-95.westeurope.logic.azure.com:443/workflows/23f06675f48646998a91d97a55a56235/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=50KJExnmWKyTiN5WwT1X8o6ekd7KAOZwqboO-VWdZig"

### wait for file to exist
Start-Sleep 5
while (!(Test-Path $filename )) { Start-Sleep 10; Write-Host "Waiting for file $filename"; }

### Post file content to relay logic app

### wait for file to contain "to sign in... "
while(!((Get-Content $filename |  Select-String "sign in" ) -ne $null ))
{
     Write-Host "Didn't find string"; 
     Get-Content $filename
     Start-Sleep 3;
}

$res = Get-Content $filename
Write-Host "res:"+$res   
$params = @{    
    mail    = $mail + ''
    message = $res + ''
}
Write-Host "Start web Request"
Invoke-WebRequest -Uri $authrelayurl -Method Post -Body ($params | ConvertTo-Json) -ContentType "application/json" -UseBasicParsing
Write-Host "sended"

### now wait for 
Start-Sleep 120

#### register vso service
sc.exe create "vso.$env:computername.$user"  binpath="c:\VSOnline\vso.exe vmagent -s -t" obj=".\$user" password=$decryptedpw start=auto
Write-Host "service created"


# ### kill process 
$proc=Get-Process vso
$proc.kill()
Write-Host "process killed"
