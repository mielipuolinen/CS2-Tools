# What: Compare two directories recursively
# Why: Helps finding differences between given directories
# For: Research, debug and reverse engineering purposes.
# Requires: -

$sourceDir = "D:\CS2-Repo\CS2-build240323"
$targetDir = "D:\CS2-Repo\CS2-build300323"
$threads = 16 # only hash calculation split into jobs

$startTime = Get-Date

Write-Host ""
Write-Host "Starting." -ForegroundColor Green

$sourceDir_test = Test-Path -LiteralPath $sourceDir -ErrorAction SilentlyContinue
$targetDir_test = Test-Path -LiteralPath $targetDir -ErrorAction SilentlyContinue
if(!$sourceDir_test -or !$targetDir_test){
    Write-Host "ERROR: Invalid dir paths. Exiting." -ForegroundColor Red
    return
}

Write-Host "Listing files." -ForegroundColor Green
$sourceItemList = Get-ChildItem -Path $sourceDir -File -Recurse
Write-Host "`tItems in sourceDir: $($sourceItemList.Count)"
$targetItemList = Get-ChildItem -Path $targetDir -File -Recurse
Write-Host "`tItems in targetDir: $($targetItemList.Count)"

function Calculate-FileHashes{
    param( $itemList )

    $itemStackSizePerJob = [math]::Round( $itemList.Count / $threads )

    $processedFileCount = 0
    $job_list = New-Object System.Collections.ArrayList

    while($processedFileCount -lt $itemList.Count){

        $countDifference = $itemList.Count - $processedFileCount
        if($countDifference -gt $itemStackSizePerJob){
            $itemStackSize = $itemStackSizePerJob
        }else{
            $itemStackSize = $countDifference
        }

        $index_start = $processedFileCount
        $index_end = $index_start + $itemStackSizePerJob - 1
        $itemStackForJob = $itemList[$index_start .. $index_end]
        $job_list.Add($(Start-Job -ScriptBlock { $using:itemStackForJob | Get-FileHash })) | Out-Null

        $processedFileCount += $itemStackSize

    }


    $itemHashes = New-Object System.Collections.ArrayList

    ForEach($job in $job_list){
        $result = Receive-Job -Job $job -Wait -AutoRemoveJob
        $itemHashes += $result | Select-Object -Property Path,Hash
    }

    Write-Output $itemHashes
}

Write-Host "Calculating source file hashes." -ForegroundColor Green
$sourceItemHashList = Calculate-FileHashes -itemList $sourceItemList
Write-Host "Calculating target file hashes." -ForegroundColor Green
$targetItemHashList = Calculate-FileHashes -itemList $targetItemList

Write-Host "Unifying file paths for hash comparison." -ForegroundColor Green
ForEach($item in $sourceItemHashList){
    $item.Path = $item.Path -replace [regex]::escape($sourceDir),""
}
ForEach($item in $targetItemHashList){
    $item.Path = $item.Path -replace [regex]::escape($targetDir),""
}

Write-Host "Processing files." -ForegroundColor Green
$unalteredItems = New-Object System.Collections.ArrayList # hash match
$alteredItems   = New-Object System.Collections.ArrayList # hash mismatch
$removedItems   = New-Object System.Collections.ArrayList # only in sourceDir
$newItems       = New-Object System.Collections.ArrayList # only in targetDir

Write-Host "`tStep 1/2"
ForEach($sourceItem in $sourceItemHashList){

    $foundMatchingName = $false

    ForEach($targetItem in $targetItemHashList){
        if($sourceItem.Path -eq $targetItem.Path){
            $foundMatchingName = $true
            break
        }
    }

    if($foundMatchingName){
        if($sourceItem.Hash -eq $targetItem.Hash){
            $unalteredItems.Add($sourceItem.Path) | Out-Null
        }else{
            $alteredItems.Add($sourceItem.Path) | Out-Null
        }
    }else{
        $removedItems.Add($sourceItem.Path) | Out-Null
    }

}


Write-Host "`tStep 2/2"
ForEach($targetItem in $targetItemHashList){
    if($unalteredItems.Contains($targetItem.Path)){
        continue
    }elseif($alteredItems.Contains($targetItem.Path)){
        continue
    }elseif($removedItems.Contains($targetItem.Path)){
        continue
    }else{
        $newItems.Add($targetItem.Path) | Out-Null
    }
}

Write-Host "Outputting results." -ForegroundColor Green
Write-Host ""
Write-Host "Altered items (hash mismatch):"
$alteredItems.Sort()
ForEach($item in $alteredItems){
    Write-Host "`t$($item)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Removed items (only in sourceDir):"
$removedItems.Sort()
ForEach($item in $removedItems){
    Write-Host "`t$($item)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "New items (only in targetDir):"
$newItems.Sort()
ForEach($item in $newItems){
    Write-Host "`t$($item)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Items in sourceDir: $($sourceItemList.Count)"
Write-Host "Items in targetDir: $($targetItemList.Count)"
Write-Host ""
Write-Host "Total counts:" -ForegroundColor Green
Write-Host "`tUnaltered Items (hash match): $($unalteredItems.Count)"
Write-Host "`tAltered Items (hash mismatch): $($alteredItems.Count)"
Write-Host "`tRemoved Items (only in sourceDir): $($removedItems.Count)"
Write-Host "`tNew Items (only in targetDir): $($newItems.Count)"

Write-Host ""
Write-Host "Finished." -ForegroundColor Green
Write-Host ""
$endTime = Get-Date
$elapsedTime = $endTime - $startTime
Write-Host "Script execution time $($elapsedTime)"