# What: Little tool to keep CS2 server alive
# Why: CS2 server is not too stable.
# For: Yes.
# Requires: CS2

$hostname = ""
$rcon_password = "" # rcon doesn't seem to work
$ip = "10.0.0.1"
$port = "27015"

[IPAddress]$ip = $hostip
$bytes = $ip.GetAddressBytes()
[Array]::Reverse($bytes)
$ip_dec = [BitConverter]::ToUInt32($bytes, 0)

$serverArgs = "-dedicated -usercon -console"
$gameArgs = "+game_type 0 +game_mode 0 +map de_dust2 +hostname $hostname +sv_lan 1 +hostip $($ip_dec) +hostport $($port)"
$customArgs = "+hostname_in_client_status true +sv_kick_players_with_cooldown 0 +rcon_password $($rcon_password)"

$processName = "cs2"
$executablePath = "C:\cs2\bin\win64\${processName}.exe"

$phase = "startup"
$status = "launching"
$running = $true

While($running){


    if($phase -eq "startup"){

        if($status -eq "launching"){
            Write-Host "Starting up the server"
        }elseif($status -eq "crashed"){
            Write-Host "Restarting the server"
        }

        $argumentList = "$ServerArgs $GameArgs $CustomArgs"
        Start-Process -FilePath $executablePath -ArgumentList $argumentList
        Write-Host "${executablePath} ${argumentList}"
        
        $sleepTimer = 10
        Write-Host "- Waiting $sleepTimer seconds for the server startup"
        Start-Sleep -Seconds $sleepTimer

        $phase = "monitor"
        $status = "running"


    }elseif($phase -eq "monitor"){

        if($status -eq "running"){
            Write-Host "Starting up the monitoring"
            $status = "monitoring"
        }

        Start-Sleep -Seconds 5
        $process = Get-Process -Name $processName -ErrorAction SilentlyContinue

        if(!$process){
            Write-Host "- WARNING: The server has crashed, restarting..."
            $phase = "startup"
            $status = "crashed"
        }else{
            Write-Host "- The server is alive"
        }


    }elseif($phase -eq "quit"){

        $running = $false
        Write-Host "Quitting"

    }else{
        Write-Host "ERROR: Invalid phase (phase: ${phase}, status:${status})"
        Write-Host "Exiting"
        Exit
    }


}
