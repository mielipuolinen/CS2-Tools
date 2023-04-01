# What: Copy CS2 game files into a work dir and convert the work dir into VPK-less game files.
# Why: Easier to work with game files and allows easier file comparison between different game versions.
# For: Research, debug and reverse engineering purposes.
# Requires: CS2 game files, VRF Decompiler (vrf.steamdb.info)

$sourceDir = "D:\CS2-Repo\CS2-build300323" # leave empty if you don't want to copy clean files into workDir first
$workDir = "D:\CS2-Repo\CS2-no_vpk-build300323"

$vpkBaseDirs = 
    "$($workDir)\bin",
    "$($workDir)\core",
    "$($workDir)\csgo",
    "$($workDir)\csgo_core",
    "$($workDir)\csgo_imported",
    "$($workDir)\csgo_lv"

##

$removeVPKfiles = $true # remove .vpk files in workDir at the end
$threads = 16 # Threading for robocopy & per .vpk file
$VRF_Decompiler_exe = "D:\CS2-Repo\VRF-Decompiler\Decompiler.exe"
$inclusion_filter = "^.*\.vpk$"
$exclusion_filter_list =
    "^.*_\d{3}\.vpk$", # skip split files (*_001.vpk, ..)
    "^shaders.*\.vpk$" # skip shader files (shaders*.vpk)

###

Write-Host ""
Write-Host "Starting." -ForegroundColor Green
Write-Host ""

$startTime = Get-Date

if($sourceDir -ne ""){
    $sourceDir_test = Test-Path -LiteralPath $sourceDir -ErrorAction SilentlyContinue
    if($sourceDir_test -eq $false){
        Write-Host "Error: sourceDir doesn't exist ($($sourceDir)). Exiting." -ForegroundColor Red
        Return
    }

    $workDir_test = Test-Path -LiteralPath $workDir -ErrorAction SilentlyContinue
    if($workDir_test -eq $true){
        Write-Host "Error: workDir already exists, please delete it ($($workDir)). Exiting." -ForegroundColor Red
        Return
    }

    Write-Host "Copying sourceDir to workDir..." -ForegroundColor Green
    robocopy "$sourceDir" "$workDir" /E /MT:$threads /NS /NC /NFL /NDL /NP /ETA
    Write-Host "Done."
}else{
    $workDir_test = Test-Path -LiteralPath $workDir -ErrorAction SilentlyContinue
        if($workDir_test -eq $false){
            Write-Host "Error: workDir doesn't exist ($($workDir)). Exiting." -ForegroundColor Red
            Exit
        }
}

Write-Host ""
Write-Host "Processing .vpk files" -ForegroundColor Green
Write-Host "Starting vpk extraction jobs for the following files:" -ForegroundColor Green
$job_list = New-Object System.Collections.ArrayList
ForEach($vpkBaseDir in $vpkBaseDirs){

    $vpkBaseDir_test = Test-Path -LiteralPath $vpkBaseDir -ErrorAction SilentlyContinue
    if($vpkBaseDir_test -eq $false){
        Write-Host "Error: vpkBaseDir doesn't exist ($($vpkBaseDir)). Exiting." -ForegroundColor Red
        Return
    }

    $itemList = Get-ChildItem $vpkBaseDir -Recurse
    ForEach($item in $itemList){

        if($item.Name -match $inclusion_filter){

            $exclude_this_file = $false
            ForEach($exclusion_filter in $exclusion_filter_list){
                if($item.Name -match $exclusion_filter){
                    $exclude_this_file = $true
                    break
                }
            }

            if($exclude_this_file -eq $true){
                continue
            }

            Write-Host "`t$($item.FullName)"

            $job_list.Add($(Start-Job -Scriptblock {
                # Output dir needs to be set manually to baseDir as VPKs have full folder structure no matter in what dir they're (e.g. maps/de_dust2.vpk)
                $process = Start-Process -WindowStyle Hidden -PassThru -FilePath $using:VRF_Decompiler_exe -ArgumentList "-i $($using:item.FullName) -o $($using:vpkBaseDir) --threads $($using:threads)" 
                # Keep job alive until the started process has exited
                while(!$process.HasExited){
                    Start-Sleep -Seconds 1
                }

            })) | Out-Null

        }

    }

}

Write-Host ""
Write-Host "Waiting for .vpk extraction jobs to finish..." -ForegroundColor Green
ForEach($job in $job_list){
    Receive-Job -Job $job -Wait -AutoRemoveJob
}
Write-Host "Done."


if($removeVPKfiles -eq $true){
    Write-Host ""
    Write-Host "Removing .vpk files from given input base dirs..." -ForegroundColor Green
    ForEach($vpkBaseDir in $vpkBaseDirs){
        $itemList = Get-ChildItem $vpkBaseDir -Recurse
        ForEach($item in $itemList){
            if($item.Name -like "*.vpk"){
                Remove-Item -Path $item.FullName
            }
        }
    }
    Write-Host "Done."
}

Write-Host ""
Write-Host "Finished." -ForegroundColor Green
Write-Host ""
$endTime = Get-Date
$elapsedTime = $endTime - $startTime
Write-Host "Script execution time $($elapsedTime)"