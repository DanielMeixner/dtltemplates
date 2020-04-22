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
Invoke-WebRequest -Uri $authrelayurl -Method Post -Body ($params | ConvertTo-Json) -ContentType "application/json" -UseBasicParsing
Write-Host "sended"

 