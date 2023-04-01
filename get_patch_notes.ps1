# What: Gets CS2 patch notes from counter-strike.net blog.
# Why: Why not?
# For: Yes.
# Requires: Selenium PowerShell, Firefox
# Note: Latest versions of Edge or Chrome doesn't seem to work well with Selenium due to major browser update in chromium's headless feature.

# Install-Module Selenium
Import-Module Selenium

$URL = "https://www.counter-strike.net/news/updates"
$CheckOnlyLatestUpdate = $false
$outputAllInDiscordFormat = $true

$Screenshot = $false
$Screenshot_FilePath = "D:\CS2-Repo\screenshot.png"

$Driver = Start-SeFirefox -Headless -Quiet -PrivateBrowsing -Arguments --width=1920,--height=1080 -AsDefaultDriver 
Enter-SeUrl $URL
Start-Sleep -Seconds 1

$XPath_ContainerElement = "//div[starts-with(@class,`"updatecapsule_UpdateCapsule`")]"
$Div_UpdateCapsules_Container = Get-SeElement -By XPath $XPath_ContainerElement

$UpdateList = New-Object System.Collections.ArrayList

if($CheckOnlyLatestUpdate){
    $UpdateCapsules_Count = 1
}else{
    $UpdateCapsules_Count = $Div_UpdateCapsules_Container.Count
}

for($i = 1; $i -le $UpdateCapsules_Count; $i++){

    # Get date from title - article date might differ
    $XPath_TitleElement = "$($XPath_ContainerElement)[$($i)]/div[starts-with(@class,`"updatecapsule_Title`")]"
    $Div_UpdateTitle = Get-SeElement -By XPath $XPath_TitleElement # "Release Notes for M/d/YYYY"
    $Date = [datetime]($Div_UpdateTitle.Text -split " ")[-1] # Split by spaces, get last split ("M/d/YYYY"), cast as datetime

    $XPath_ContentElement = "$($XPath_ContainerElement)[$($i)]/div[starts-with(@class,`"updatecapsule_Desc`")]"
    $Div_UpdateContent = Get-SeElement -By XPath $XPath_ContentElement
    $Content = [string]$Div_UpdateContent.Text


    # Updates posted after the limited test release date
    if($Date -le [datetime]"22 March 2023"){
        break
    }

    $Update = New-Object PSObject -Property @{
        Date = $Date
        Content = $Content
    }

    $UpdateList.Add($Update) | Out-null
}


if($outputAllInDiscordFormat){
    foreach($Update in $UpdateList){

        $Date = (Get-Date $Update.Date -Format "dd.MM.yyyy")

        Write-Host "`n---`n"
        Write-Host "**Update $($Date)**" -ForegroundColor Green
        Write-Host "``````ini`n$($Update.Content)``````"
        Write-Host ""
    }

    Write-Host "`n---`n"
}

if($screenshot){
    $HTML = Get-SeElement -Selection html
    $WebsiteHeight = $HTML.Size.Height + 75 #75 compensate for window borders
    Stop-SeDriver
    $Driver = Start-SeFirefox -Headless -Quiet -PrivateBrowsing -Arguments --width=1920,--height=$($WebsiteHeight) -AsDefaultDriver 
    Enter-SeUrl $URL
    Start-Sleep -Seconds 1
    New-SeScreenshot -Path $Screenshot_FilePath
}

Stop-SeDriver