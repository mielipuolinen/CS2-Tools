<#
.SYNOPSIS
Download & Install Counter-Strike 2
.EXAMPLE
Set-ExecutionPolicy Bypass -Scope Process -Force; iex "&{$(irm https://github.com/mielipuolinen/CS2-Tools/raw/main/InstallCS2.ps1)} -InstallDir 'C:\temp\CS2' -Threads 20"
#>

[CmdletBinding()]
Param(
    [Parameter(HelpMessage="Install directory for CS2, e.g. `"C:\temp\CS2`"")]
    [ValidateNotNullOrEmpty()]
    [String] $InstallDir = "C:\Temp\CS2",

    # 20 seems to be optimal - highest download speed with least overhead
    # If the downloader causes CPU freezing, try halving the number
    [Parameter(HelpMessage="Downloader threads, e.g. 20.")]
    [ValidateNotNullOrEmpty()]
    [Int] $Threads = 20,

    [Parameter(HelpMessage="Likely no reason to change.")]
    [ValidateNotNullOrEmpty()]
    [String] $URI_DepotKeysJSON = "https://raw.githubusercontent.com/mielipuolinen/CS2-Tools/main/Depot%20Files/Depot%20Keys.json",

    [Parameter(HelpMessage="Likely no reason to change.")]
    [ValidateNotNullOrEmpty()]
    [String] $URI_DepotFilesJSON = "https://github.com/mielipuolinen/CS2-Tools/raw/main/Depot%20Files/Depot%20Files.json"
)

Write-Host "`nLaunching CS2 Downloader Tool`n---`n"
$ScriptStartTime = Get-Date

### Create CS2 Install Directory

try{
    Write-Host "CS2 Installation Directory"
    Write-Host "`t$CS2InstallDirPath"
    if(!(Test-Path $CS2InstallDirPath)){ New-Item -ItemType Directory -Path $CS2InstallDirPath }
}catch{
    Write-Host "ERROR: $_"
    Return
}

### Install Chocolatey

try{
    Write-Host "Install Chocolatey"

    try{
        if(Get-Command -Name "choco" -ErrorAction Stop){ $IsInstalled = $True }
    }catch{
        $IsInstalled = $False
    }

    if($IsInstalled){
        Write-Host "`tAlready Installed"
    }else{
        Write-Host "`tInstalling"

        Start-Job -Name "InstallChoco" -ScriptBlock{
            Invoke-Expression "`& {$(Invoke-RestMethod https://community.chocolatey.org/install.ps1)}"
        } | Out-Null
        
        while(((Get-Job -Name "InstallChoco").JobStateInfo | Where-Object State -eq "Running").count -gt 0){
            Start-Sleep -Seconds 1
        }

        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" `
                  + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "`tOK"
    }
}catch{
    Write-Host "ERROR: $_"
    Return
}finally{
    Get-Job -Name "InstallChoco" | Stop-Job | Remove-Job *>$null
}

### Install Python

try{
    Write-Host "Install Python"

    try{
        if(Get-Command -Name "py" -ErrorAction Stop){ $IsInstalled = $True }
    }catch{
        $IsInstalled = $False
    }

    if($IsInstalled){
        Write-Host "`tAlready Installed"
    }else{
        Write-Host "`tInstalling"

        Start-Job -Name "InstallPython" -ScriptBlock{
            choco install python -y --limit-output
        } | Out-Null
        
        while(((Get-Job -Name "InstallPython").JobStateInfo | Where-Object State -eq "Running").count -gt 0){
            Start-Sleep -Seconds 1
        }

        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" `
                  + [System.Environment]::GetEnvironmentVariable("Path","User")

        Write-Host "`tOK"
    }

}catch{
    Write-Host "ERROR: $_"
    Return
}finally{
    Get-Job -Name "InstallPython" | Stop-Job | Remove-Job *>$null
}

### Install SteamCTL

try{
    Write-Host "Install SteamCTL"

    try{
        if(Get-Command -Name "steamctl" -ErrorAction Stop){ $IsInstalled = $True }
    }catch{
        $IsInstalled = $False
    }

    if($IsInstalled){
        Write-Host "`tAlready Installed"
    }else{
        Write-Host "`tInstalling"
        Start-Job -Name "InstallSteamCTL" -ScriptBlock{
            pip install steamctl
        } | Out-Null
        
        while(((Get-Job -Name "InstallSteamCTL").JobStateInfo | Where-Object State -eq "Running").count -gt 0){
            Start-Sleep -Seconds 1
        }

        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" `
                  + [System.Environment]::GetEnvironmentVariable("Path","User")

         Write-Host "`tOK"
    }

}catch{
    Write-Host "ERROR: $_"
    Return
}finally{
    Get-Job -Name "InstallSteamCTL" | Stop-Job | Remove-Job *>$null
}

### Get Decryption Keys

try{
    Write-Host "Get Decryption Keys"
    $SteamCTLDirPath = "$($Env:LOCALAPPDATA)\steamctl\steamctl"
    if(!(Test-Path $SteamCTLDirPath)){ New-Item -ItemType Directory -Path $SteamCTLDirPath }

    $URI = $URI_DepotKeysJSON
    Invoke-RestMethod $URI -OutFile "$($SteamCTLDirPath)\depot_keys.json"

    Write-Host "`tOK"

}catch{
    Write-Host "ERROR: $_"
    Return
}

### Get Depot Files

try{
    Write-Host "Get Depot Files"

    $URI = $URI_DepotFilesJSON
    $DepotFiles = Invoke-RestMethod $URI

    $Depot_Others = @()
    $FileCounter = 0

    foreach($Depot in $DepotFiles){

        $FileCounter += 1
        $FileName = ($Depot -split "/")[-1]
        $FilePath = "$($CS2InstallDirPath)\$($FileName)"
        Invoke-RestMethod $Depot -OutFile $FilePath
        
        if($FileCounter -eq 1){
            $Depot_Main = $FilePath
        }else{
            $Depot_Others += $FilePath
        }

    }

    if(!(Test-Path $Depot_Main)){
        Throw "Unable to find main depot file:`n$($Depot_Main)"
    }

    foreach($Depot in $Depot_Others){
        if(!(Test-Path $Depot)){
            Throw "Unable to find depot file:`n$($Depot)"
        }
    }

    Write-Host "`tOK"

}catch{
    Write-Host "ERROR: $_"
    Return
}

### Download CS2

try{
    Write-Host "CS2 Downloader"
    Write-Host "`tCTRL+C to Exit"
    Write-Host "`tNote: In case of high CPU usage, try halving the threads parameter's value."
    Write-Progress -Activity "Downloader" -Status "Starting threads..."

    $List = steamctl depot list -f $Depot_Main | Sort-Object {Get-Random}

    $FileCount = $List.count
    if($FileCount -eq 0){ Throw "Failed to get a list of files." }

    $DownloaderThreads = $Threads - $Depot_Others.count
    $FilesPerThread = [math]::Ceiling( $FileCount / $DownloaderThreads )
    $StartIndex = 0
    $TimeStart = Get-Date

    for($i = 1; $i -le $DownloaderThreads; $i++){
        $Group = $List | Select-Object -Skip $StartIndex -First $FilesPerThread
        $Group = $Group | Sort-Object { if($_ -like "*.vpk"){0}else{1} }
        $Regex = ( $Group | ForEach-Object{[regex]::Escape($_)} ) -join "|"

        Start-Job -Name "DownloadCS2_Main_t$i" -ScriptBlock {
            steamctl depot download -f $using:Depot_Main -o $using:CS2InstallDirPath -re $using:Regex `
            --skip-licenses --skip-login 
        } | Out-Null

        $StartIndex += $FilesPerThread
    }

    $Depot_Others_Count = 0
    foreach($Depot in $Depot_Others){
        $FileCount += (steamctl depot list -f $Depot).count
        $Depot_Others_Count += 1
        Start-Job -Name "DownloadCS2_Depot-$($Depot_Others_Count)" -ScriptBlock {
            steamctl depot download -f $using:Depot -o $using:CS2InstallDirPath --skip-licenses --skip-login
        } | Out-Null
    }

    while(((Get-Job -Name "DownloadCS2*").JobStateInfo | Where-Object State -eq "Running").count -gt 0){
        $ActiveDownloads = ((Get-Job -Name "DownloadCS2*").JobStateInfo | Where-Object State -eq "Running").count
        $CurrentFileCount = (Get-ChildItem $CS2InstallDirPath -Recurse -File).count - $ActiveDownloads
        $Percentage = $CurrentFileCount / $FileCount * 100 
        $Status = "Files: $CurrentFileCount/$FileCount | Active Threads: $ActiveDownloads"
        Write-Progress -Activity "Downloader" -Status $Status -PercentComplete $Percentage
        Start-Sleep -Seconds 1
    }

    $TimeDiff = ((Get-Date) - $TimeStart).TotalSeconds
    $DirSize = (Get-ChildItem $CS2InstallDirPath -Recurse | Measure-Object -Property Length -Sum).Sum
    $DirSizeInMegaBits = $DirSize * 8 / 1000000
    $SpeedInMbitsperSecond = [math]::Round( $DirSizeInMegaBits / $TimeDiff )

    Write-Host "`tDownload finished!"
    Write-Host "`tOutput: $CS2InstallDirPath"
    Write-Host "`tDownload speed: $SpeedInMbitsperSecond Mbps"

}catch{
    Write-Host "ERROR: $_"
    Return
}finally{
    Write-Progress -Activity "Downloader" -Status "Exiting, please wait..."
    Get-Job -Name "DownloadCS2*" | Stop-Job | Remove-Job *>$null
}

### Patch Client

$PatchTool = @"
import os
def read_file(filename):
    with open(filename,'rb')as file:return bytearray(file.read())
def find_byte_array(buffer,byte_array):
    positions=[];buffer_size=len(buffer);array_size=len(byte_array)
    for i in range(buffer_size-array_size+1):
        found=True
        for j in range(array_size):
            if buffer[i+j]!=byte_array[j]:found=False;break
        if found:positions.append(i)
    return positions
def write_file(filename,buffer):
    with open(filename,'wb')as file:file.write(buffer)
def patch_file(filename,original_array,replaced_array):
    buffer=read_file(filename);positions=find_byte_array(buffer,original_array)
    if not positions:print('Failed');return
    for pos in positions:
        for i in range(len(original_array)):buffer[pos+i]=replaced_array[i]
    write_file(filename,buffer);print('OK')
def main():file_path='client.dll';patch_file(file_path,bytearray([117,115,255,21]),bytearray([235,115,255,21]))
if __name__=='__main__':main()
"@

try{
    Write-Host "Patching Client"
    $ClientDLLDirPath = "$($CS2InstallDirPath)\game\csgo\bin\win64"
    $PatchTool | Out-File "$($ClientDLLDirPath)\patch.py"

    Start-Job -Name "ClientPatcher" -ScriptBlock {
        Set-Location $using:ClientDLLDirPath
        py "patch.py"
    } | Out-Null

}catch{
    Write-Host "ERROR: $_"
    Return
}

### Create CS2 Shortcut

try{
    Write-Host "Creating Shortcut"
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$($CS2InstallDirPath)\Launch CS2.lnk")
    $Shortcut.TargetPath = "$($CS2InstallDirPath)\game\bin\win64\cs2.exe"
    $Shortcut.Arguments = "-insecure +showconsole +cl_join_advertise 2 +hostname_in_client_status true"
    $Shortcut.Save()
    Write-Host "`tOK"
}catch{
    Write-Host "ERROR: $_"
    Return
}

### Open Explorer

Write-Host "`nFinished!"
Write-Host "Runtime: $((Get-Date)-$ScriptStartTime)`n"
Invoke-Item $CS2InstallDirPath
