function Test-Ping {
    [CmdletBinding()]
    Param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Computer,

        [Parameter()]
        [int]$BufferSize = 1472,

        [Parameter()]
        [Boolean]$DontFragment = $true,

        [Parameter()]
        [int]$Count = 100000,
    
        [Parameter()]
        [int]$Interval = 5,
    
        [Parameter()]
        [string]$LogPath = "$env:USERPROFILE\Documents\PingResults\PingLoop.csv"
    )

    $Ping = @()
    #Test if path exists, if not, create it
    if (!(Test-Path (Split-Path $LogPath) -PathType Container)) {
        Write-Host "$(Get-Date) : Folder doesn't exist $(Split-Path $LogPath), creating..." -ForegroundColor Cyan
        New-Item (Split-Path $LogPath) -ItemType Directory | Out-Null
    }

    #Test if log file exists, if not add a header row
    If (!(Test-Path $LogPath))
    {   Write-Host "$(Get-Date) : Log file doesn't exist: $($LogPath), creating..." -ForegroundColor Cyan
        Add-Content -Value '"TimeStamp","Source","Destination","IPV4Address","ResponseTime","BufferSize","NoFragmentation","Status","StatusCode"' -Path $LogPath
    }

    # Perform the ping loop
    Write-Host "$(Get-Date) : Beginning ping monitoring of $Computer" -ForegroundColor Cyan
    Write-Host Write-Host "Time zone is currently set for $((Get-TimeZone).DisplayName) $((Get-TimeZone).BaseUtcOffset.TotalHours)" -ForegroundColor Cyan
    Write-Host "$(Get-Date) : 
    Destination: $Computer
    NoFragmentation: $DontFragment
    BufferSize: $BufferSize
    Count: $Count
    Interval: $Interval" -ForegroundColor Cyan

    Write-Host "========================`n`n" -ForegroundColor Cyan
    Write-Host "TimeStamp | Source | Destination | IPv4Address | ResponseTime | BufferSize | NoFragmentation | Status | StatusCode" -ForegroundColor Cyan
    $i=0
    do {
        $i++

        # Pass different parameters if DontFragment defined
        if($DontFragment -eq $true) {
            $Ping = Get-WmiObject Win32_PingStatus -Filter "Address = '$Computer' and NoFragmentation='$DontFragment' and BufferSize=$BufferSize" | Select-Object @{Label="TimeStamp";Expression={Get-Date}},@{Label="Source";Expression={ $_.__Server }},@{Label="Destination";Expression={ $_.Address }},IPv4Address,@{Label="Status";Expression={ If ($_.StatusCode -ne 0) {"Failed"} Else {"Success"}}},StatusCode, ResponseTime, BufferSize, NoFragmentation
        }
        elseif($DontFragment -eq $false)
        {
            $Ping = Get-WmiObject Win32_PingStatus -Filter "Address = '$Computer' and BufferSize=$BufferSize" | Select-Object @{Label="TimeStamp";Expression={Get-Date}},@{Label="Source";Expression={ $_.__Server }},@{Label="Destination";Expression={ $_.Address }},IPv4Address,@{Label="Status";Expression={ If ($_.StatusCode -ne 0) {"Failed"} Else {"Success"}}},StatusCode, ResponseTime, BufferSize, NoFragmentation
        }

        # Throw message if failure detected for ping result
        if($ping.Status -eq "Failed") {
            Write-Host "$(($Ping | Select-Object TimeStamp,Source,Destination,IPv4Address,ResponseTime,BufferSize,NoFragmentation,Status,StatusCode | Format-Table -AutoSize -HideTableHeaders | Out-String).Trim())" -ForegroundColor Red
        }
        else {
            Write-Host "$(($Ping | Select-Object TimeStamp,Source,Destination,IPv4Address,ResponseTime,BufferSize,NoFragmentation,Status,StatusCode | Format-Table -AutoSize -HideTableHeaders | Out-String).Trim())" -ForegroundColor Green
        }

        # Save the results of the ping test to the csv
        $Result = $Ping | Select-Object TimeStamp,Source,Destination,IPv4Address,ResponseTime,BufferSize,NoFragmentation,Status,StatusCode | ConvertTo-Csv -NoTypeInformation
        $Result[1] | Add-Content -Path $LogPath

        # Pause per the interval duration defined
        Start-Sleep -Seconds $Interval
    } until ($i -ge $Count)

    if ($i -ge $Count) {
        Write-Host "$(Get-Date) : Script has reached $i of $Count retries" -ForegroundColor Cyan
    }
}
