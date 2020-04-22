[CmdletBinding()]
param(
    # .
    [string] $mail

    

    
)


Set-StrictMode -Version Latest


$args = " stop "
Write-Host "argslist: " + $args


### register for vso; vso start --service ...
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 

Start-Process C:\VSonline\vso.exe  -ArgumentList $args -RedirectStandardOutput .\uninstall.txt -WindowStyle Hidden -RedirectStandardInput .\input.txt
 
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

 