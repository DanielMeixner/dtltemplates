[CmdletBinding()]
param(
    # .
    [string] $mail

    

    
)


Set-StrictMode -Version Latest


$args = " stop "
Write-Host "argslist: " + $args

$outfilename = ".\output.txt"
### register for vso; vso start --service ...
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 

Start-Process C:\VSonline\vso.exe  -ArgumentList $args  -WindowStyle Hidden -RedirectStandardInput .\input.txt -RedirectStandardOutput $outfilename
 
# dirty for now - later wait for file being created and filled.
Start-Sleep 5

$res = Get-Content $outfilename
 
Write-Host "res:"+$res
    
$params = @{    
    mail    = $mail + ''
    message = $res + ''
}

$authrelayurl = "https://prod-95.westeurope.logic.azure.com:443/workflows/23f06675f48646998a91d97a55a56235/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=50KJExnmWKyTiN5WwT1X8o6ekd7KAOZwqboO-VWdZig"

Invoke-WebRequest -Uri $authrelayurl -Method Post -Body ($params | ConvertTo-Json) -ContentType "application/json" -UseBasicParsing
Write-Host "sended"

 