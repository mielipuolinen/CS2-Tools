# What: -
# Why: -
# For: Researching purposes.
# Requires: CS2

$ClientDLL_Path = "" # ..\csgo\bin\win64\client.dll
$ClientDLL_Patched_Path = "$($ClientDLL_Path).patched"
$ClientDLL_Backup_Path = "$($ClientDLL_Path).backup"

$Signature = @( 0x70, 0xFF, 0x15, 0x0D,
                0xEE, 0x51, 0x00, 0x48,
                0x8D, 0x15, 0x9E, 0x7F,
                0x60, 0x00              )

$Offset       = -0x01 # Patch offset of signature
$OriginalByte = 0x75  # JNZ instruction
$PatchedByte  = 0xEB  # JMP instruction

$startTime = Get-Date
Write-Host "Starting." -ForegroundColor Green

$ClientDLL_Test = Test-Path -Path $ClientDLL_Path -ErrorAction SilentlyContinue
if(!$ClientDLL_Test -or !$ClientDLL_Path){
    Write-Host "ERROR: Unable to find client.dll file, exiting." -ForegroundColor Red
    return
}else{
    Write-Host "Found the file." -ForegroundColor Green
}

Write-Host "Reading bytes of the file." -ForegroundColor Green
$ClientDLL = [System.IO.File]::ReadAllBytes($ClientDLL_Path)
$byteCount = $ClientDLL.Count
$SignatureByteLength = $Signature.Count

Write-Host "Searching for the signature." -ForegroundColor Green
for($i=0; $i -lt $byteCount - $SignatureByteLength; $i++){

    # Optimization hack: quick first byte validation
    if($ClientDLL[$i] -ne $Signature[0]){
        continue
    }

    $mismatch = $false
    for($j=1; $j -lt $SignatureByteLength; $j++){
        if($ClientDLL[$i+$j] -ne $Signature[$j]){
            $mismatch = $true
            break
        }
    }

    if($mismatch){
        continue
    }

    Write-Host "Found the signature." -ForegroundColor Green
    $Offset += $i
    break
}

if($ClientDLL[$Offset] -eq $OriginalByte){
    Write-Host "This is a non-patched file, starting patching." -ForegroundColor Green
}elseif($ClientDLL[$Offset] -eq $PatchedByte){
    Write-Host "This is already a patched file, exiting." -ForegroundColor Yellow
    return
}else{
    Write-Host "ERROR: Unexpected byte at the offset, exiting." -ForegroundColor Red
    return
}

$ClientDLL[$Offset] = $PatchedByte

[System.IO.File]::WriteAllBytes($ClientDLL_Patched_Path, $ClientDLL)
Move-Item -Path $ClientDLL_Path -Destination $ClientDLL_Backup_Path
Move-item -Path $ClientDLL_Patched_Path -Destination $ClientDLL_Path

Write-Host "Finished." -ForegroundColor Green

$endTime = Get-Date
$elapsedTime = $endTime - $startTime
Write-Host "`nScript execution time $($elapsedTime)"