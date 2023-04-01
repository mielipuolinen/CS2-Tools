# What: Compare two directories recursively
# Why: Helps finding differences between given directories
# For: Research, debug and reverse engineering purposes.
# Requires: -

$sourceDir = "D:\CS2-Repo\CS2-no_vpk-build240323"
$targetDir = "D:\CS2-Repo\CS2-no_vpk-build300323"
$threads = 32 # only hash calculation split into jobs

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

$initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $threads, $initialSessionState, $Host)
$runspacePool.Open()

Write-Host "Calculating file hashes." -ForegroundColor Green
$higherItemCount = [math]::Max($sourceItemList.Count, $targetItemList.Count)
$chunkSize = [math]::Ceiling($higherItemCount / $threads)
$jobList = New-Object System.Collections.ArrayList
for($i = 0; $i -lt $threads; $i++){
    $startIndex = $i * $chunkSize
    $endIndex_sourceItems = [math]::Min($startIndex + $chunkSize - 1, $sourceItemList.Count - 1)
    $endIndex_targetItems = [math]::Min($startIndex + $chunkSize - 1, $targetItemList.Count - 1)

    ## Check if unprocessed source items left
    if($startIndex -le $endIndex_sourceItems){
        $sourceItemListChunk = $sourceItemList[$startIndex..$endIndex_sourceItems]
    }else{
        $sourceItemListChunk = $false
    }

    # Check if unprocessed target items left
    if($startIndex -le $endIndex_targetItems){
        $targetItemListChunk = $targetItemList[$startIndex..$endIndex_targetItems]
    }else{
        $targetItemListChunk = $false
    }

    $job = [powershell]::Create().AddScript({
        param($sourceItemListChunk, $targetItemListChunk)

        $results = New-Object PSObject -Property @{
            SourceItemHashList = New-Object System.Collections.ArrayList
            TargetItemHashList = New-Object System.Collections.ArrayList
        }

        if($sourceItemListChunk){
            foreach($sourceItem in $sourceItemListChunk){
                $results.SourceItemHashList.Add(( $sourceItem | Get-FileHash ))
            }
        }
        
        if($targetItemListChunk){
            foreach($targetItem in $targetItemListChunk){
                $results.TargetItemHashList.Add(( $targetItem | Get-FileHash ))
            }
        }

        return $results
    }).AddArgument($sourceItemListChunk).AddArgument($targetItemListChunk)

    $job.RunspacePool = $runspacePool
    $jobList.Add(@{ Job = $job; Handle = $job.BeginInvoke() }) | Out-Null
}

$sourceItemHashList = New-Object System.Collections.ArrayList
$targetItemHashList = New-Object System.Collections.ArrayList

foreach($job in $jobList){
    $results = $job.Job.EndInvoke($job.Handle)

    if($results.SourceItemHashList.Count -gt 0){
        foreach($sourceItemHash_PSCustomObject in $results.SourceItemHashList){
            $sourceItemHash = @{
                Path = $sourceItemHash_PSCustomObject.Path
                Hash = $sourceItemHash_PSCustomObject.Hash
            }
            $sourceItemHashList.Add($sourceItemHash) | Out-Null
        }
    }

    if($results.TargetItemHashList.Count -gt 0){
        foreach($targetItemHash_PSCustomObject in $results.TargetItemHashList){
            $targetItemHash = @{
                Path = $targetItemHash_PSCustomObject.Path
                Hash = $targetItemHash_PSCustomObject.Hash
            }
            $targetItemHashList.Add($targetItemHash) | Out-Null
        }
    }

    $job.Job.Dispose()
}


Write-Host "Unifying file paths for hash comparison." -ForegroundColor Green
foreach($item in $sourceItemHashList){
    $item.Path = $item.Path -replace [regex]::escape($sourceDir),""
}
foreach($item in $targetItemHashList){
    $item.Path = $item.Path -replace [regex]::escape($targetDir),""
}

Write-Host "Processing files." -ForegroundColor Green

Write-Host "`tStep 1/2"
$chunkSize = [math]::Ceiling($sourceItemHashList.Count / $threads)
$jobList = New-Object System.Collections.ArrayList

for($i = 0; $i -lt $threads; $i++){
    $startIndex = $i * $chunkSize
    $endIndex = [math]::Min($startIndex + $chunkSize - 1, $sourceItemHashList.Count - 1)
    $sourceItemHashListChunk = $sourceItemHashList[$startIndex..$endIndex]

    $job = [powershell]::Create().AddScript({
        param($sourceItemHashListChunk, $targetItemHashList)

        $results = New-Object PSObject -Property @{
            Unaltered = New-Object System.Collections.ArrayList
            Altered   = New-Object System.Collections.ArrayList
            Removed   = New-Object System.Collections.ArrayList
        }

        foreach($sourceItem in $sourceItemHashListChunk){
            $foundMatchingName = $false

            foreach($targetItem in $targetItemHashList){
                if($sourceItem.Path -eq $targetItem.Path){
                    $foundMatchingName = $true
                    break
                }
            }

            if($foundMatchingName){
                if($sourceItem.Hash -eq $targetItem.Hash) {
                    $results.Unaltered.Add($sourceItem.Path) | Out-Null
                }else{
                    $results.Altered.Add($sourceItem.Path) | Out-Null
                }
            }else{
                $results.Removed.Add($sourceItem.Path) | Out-Null
            }
        }

        return $results
    }).AddArgument($sourceItemHashListChunk).AddArgument($targetItemHashList)

    $job.RunspacePool = $runspacePool
    $jobList.Add(@{ Job = $job; Handle = $job.BeginInvoke() }) | Out-Null
}

$unalteredItems = New-Object System.Collections.ArrayList # hash match
$alteredItems   = New-Object System.Collections.ArrayList # hash mismatch
$removedItems   = New-Object System.Collections.ArrayList # only in sourceDir
$newItems       = New-Object System.Collections.ArrayList # only in targetDir

foreach ($job in $jobList) {
    $results = $job.Job.EndInvoke($job.Handle)

    if($results.Unaltered.Count -eq 1){
        $unalteredItems.Add($results.Unaltered) | Out-Null
    }elseif($results.Unaltered.Count -gt 1){
        $unalteredItems.AddRange($results.Unaltered) | Out-Null
    }

    if($results.Altered.Count -eq 1){
        $alteredItems.Add($results.Altered) | Out-Null
    }elseif($results.Altered.Count -gt 1){
        $alteredItems.AddRange($results.Altered) | Out-Null
    }

    if($results.Removed.Count -eq 1){
        $removedItems.Add($results.Removed) | Out-Null
    }elseif($results.Removed.Count -gt 1){
        $removedItems.AddRange($results.Removed) | Out-Null
    }

    $job.Job.Dispose()
}

Write-Host "`tStep 2/2"
$chunkSize = [math]::Ceiling($targetItemHashList.Count / $threads)
$jobList = New-Object System.Collections.ArrayList

for($i = 0; $i -lt $threads; $i++){
    $startIndex = $i * $chunkSize
    $endIndex = [math]::Min($startIndex + $chunkSize - 1, $targetItemHashList.Count - 1)
    $targetItemHashListChunk = $targetItemHashList[$startIndex..$endIndex]

    $job = [powershell]::Create().AddScript({
        param($targetItemHashListChunk, $unalteredItems, $alteredItems, $removedItems)

        $results = New-Object PSObject -Property @{
            NewItem = New-Object System.Collections.ArrayList
        }

        foreach($targetItem in $targetItemHashListChunk){

            if($unalteredItems.Contains($targetItem.Path)){
                continue
            }elseif($alteredItems.Contains($targetItem.Path)){
                continue
            }elseif($removedItems.Contains($targetItem.Path)){
                continue
            }else{
                $results.NewItem.Add($targetItem.Path) | Out-Null
            }

        }

        return $results
    }).AddArgument($targetItemHashListChunk).AddArgument($unalteredItems).AddArgument($alteredItems).AddArgument($removedItems)

    $job.RunspacePool = $runspacePool
    $jobList.Add(@{ Job = $job; Handle = $job.BeginInvoke() }) | Out-Null
}

foreach ($job in $jobList) {
    $results = $job.Job.EndInvoke($job.Handle)

    if($results.NewItem.Count -eq 1){
        $newItems.Add($results.NewItem) | Out-Null
    }elseif($results.NewItem.Count -gt 1){
        $newItems.AddRange($results.NewItem)
    }

    $job.Job.Dispose()
}

$runspacePool.Close()
$runspacePool.Dispose()


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
Write-Host "Total counts:" -ForegroundColor Green
Write-Host "`tItems in sourceDir: $($sourceItemList.Count)"
Write-Host "`tItems in targetDir: $($targetItemList.Count)"
Write-Host "`t---"
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