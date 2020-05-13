[CmdletBinding()]
param(
    # mail address will be used to send auth code
    [string] $mail,

    # password for user on machine, needed for registration of service
    [string] $decryptedpw = "no-pw",

    # user which will be used for running service. needs logonAsService permissions
    [string] $user = "no-user",
    
    # name of file to be watched for content
    [string] $filename,

    [string] $authrelayurl

)

Write-Host "Start watcher for file $filename ..." 


### wait for file to exist
while (!(Test-Path $filename )) { Start-Sleep 10; Write-Host "Waiting for file $filename"; }

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

### Post file content to relay logic app
Invoke-WebRequest -Uri $authrelayurl -Method Post -Body ($params | ConvertTo-Json) -ContentType "application/json" -UseBasicParsing
Write-Host "Posted to service."

### now wait for some additional time to make sure registration is completed by vso.exe running as a process already.
while(!((Get-Content $filename |  Select-String "All done" ) -ne $null ))
{
     Write-Host "Waiting for registration to complete ..."; 
     Get-Content $filename
     Start-Sleep 3;
}


#### register vso service
sc.exe create "vso.$env:computername.$user"  binpath="c:\VSOnline\vso.exe vmagent -s -t" obj=".\$user" password=$decryptedpw start=auto
Write-Host "Service created."


# ### kill process 
$proc=Get-Process vso
$proc.kill()
Write-Host "Process killed."
