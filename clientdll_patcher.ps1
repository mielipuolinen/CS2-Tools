# What: -
# Why: -
# For: Researching purposes.
# Requires: CS2

$ClientDLL_Path        = "" # ..\csgo\bin\win64\client.dll
$ClientDLL_Backup_File = "client.backup.dll"

[byte[]]$Signature = @( 0x70, 0xFF, 0x15, 0x0D,
                        0xEE, 0x51, 0x00, 0x48,
                        0x8D, 0x15, 0x9E, 0x7F,
                        0x60, 0x00              )

$SignatureOffset = -0x01 # Patch offset of signature
$OriginalByte    =  0x75 # JNZ instruction
$PatchedByte     =  0xEB # JMP instruction

function Timestamp{
    param([string[]]$Task = "Stamp")
    Switch ($Task){
        "Start" {return (Get-Date)}
        "End"   {return ((Get-Date) - $StartTime)}
        "Stamp" {return ("[$(Get-Date -Format "dd.MM.yy HH.mm.ss")] ")}
    }
}

$StartTime = Timestamp -Task Start
Write-Host "`n$(Timestamp)Starting" -ForegroundColor Green

$ClientDLL_Path = Resolve-Path -Path $ClientDLL_Path -ErrorAction SilentlyContinue
$ClientDLL_Test = Test-Path -Path $ClientDLL_Path -ErrorAction SilentlyContinue

if(!$ClientDLL_Test -or !$ClientDLL_Path){
    Write-Host "$(Timestamp)ERROR: Unable to find client.dll - Exiting" -ForegroundColor Red
    return
}else{
    Write-Host "$(Timestamp)Found file" -ForegroundColor Green
    Write-Host "`t$($ClientDLL_Path)"
}

Write-Host "$(Timestamp)Reading file" -ForegroundColor Green
[byte[]]$ClientDLL = [System.IO.File]::ReadAllBytes($ClientDLL_Path)
$ClientDLL_ByteLength = $ClientDLL.Length
Write-Host "`tSize: $($ClientDLL_ByteLength) Bytes"

Write-Host "$(Timestamp)Reading signature" -ForegroundColor Green
$Signature_ByteLength = $Signature.Length
Write-Host "`tSignature: $(foreach($byte in $Signature){"0x{0:X2}" -f $byte})"
Write-Host "`tSize: $($Signature_ByteLength) Bytes"
Write-Host "`tOffset: $(if(($x=$SignatureOffset) -lt 0){"-0x{0:X2}" -f ($x*-1)}else{"0x{0:X2}" -f $x})"

Write-Host "$(Timestamp)Searching for signature match" -ForegroundColor Green
$Offset = 0
for($i=0; $i -lt $ClientDLL_ByteLength; $i++){

    # Optimization hack: validate first byte before attempting to match signature
    if($ClientDLL[$i] -ne $Signature[0]){
        continue
    }

    $Match = $True
    for($j=1; $j -lt $Signature_ByteLength; $j++){
        if($ClientDLL[$i+$j] -ne $Signature[$j]){
            $Match = $False
            break
        }
    }

    if($Match){
        Write-Host "$(Timestamp)Found signature match" -ForegroundColor Green
        $Offset = $SignatureOffset + $i
        break
    }

}

if(!$Offset){
    Write-Host "$(Timestamp)ERROR: Signature match not found - Exiting" -ForegroundColor Red
    return
}

if($ClientDLL[$Offset] -eq $OriginalByte){
    Write-Host "$(Timestamp)Non-patched file" -ForegroundColor Green
}elseif($ClientDLL[$Offset] -eq $PatchedByte){
    Write-Host "$(Timestamp)Already patched - Exiting" -ForegroundColor Yellow
    return
}else{
    Write-Host "$(Timestamp)ERROR: Unexpected byte at offset - Exiting" -ForegroundColor Red
    return
}

$ClientDLL_Patched_Path = "$($ClientDLL_Path).patched"

Write-Host "$(Timestamp)Creating patched version" -ForegroundColor Green
Write-Host "`tByte at offset: $("0x{0:X2}" -f $ClientDLL[$Offset])"
Write-Host "`tPatched byte: $("0x{0:X2}" -f $PatchedByte)"
$ClientDLL[$Offset] = $PatchedByte
[System.IO.File]::WriteAllBytes($ClientDLL_Patched_Path, $ClientDLL)

Write-Host "$(Timestamp)Backing up original file" -ForegroundColor Green
Write-Host "`t$($ClientDLL_Backup_Path)"
Move-Item -Path $ClientDLL_Path -Destination $ClientDLL_Backup_Path

Write-Host "$(Timestamp)Writing patched file" -ForegroundColor Green
Write-Host "`t$($ClientDLL_Path)"
Move-item -Path $ClientDLL_Patched_Path -Destination $ClientDLL_Path

Write-Host "$(Timestamp)Finished" -ForegroundColor Green
Write-Host "`nScript execution time $(Timestamp -Task End)"