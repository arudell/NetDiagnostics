[string]$tenantTraceFilePath = "C:\Temp\MSFT_CSS"
[string]$outputDirectory = "C:\Temp\MSFT_CSS"
[string]$LogName = '{logname}'
[string]$errorMessage = '{insert error message}'

[string]$appVMIPAddress  = 'xxx.xx.xx.xx'
$appVMCred = Get-Credential -Message "Provide credentials for $appVMIPAddress"

[string]$sqlVMIPAddress  = 'xxx.xx.xx.xx'
$sqlVMCred = Get-Credential -Message "Provide credentials for $sqlVMIPAddress"

#### start functions ####

function Enable-TenantTracing {
    param (
        [Parameter(Mandatory = $true)]
        [String]$IPAddress,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$FilePath,

        [Parameter(Mandatory = $false)]
        [System.Int16]$MaxSize = 256
    )

    $enableTracing = {
        if(-NOT (Test-Path -Path $using:FilePath.FullName -PathType Container)) {
            $null = New-Item -Path $using:FilePath.FullName -ItemType Directory -Force
        }

        $subString = "{0}_{1}_Trace.etl" -f $env:COMPUTERNAME, ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
        $fileName = Join-Path -Path $using:FilePath.FullName -ChildPath $subString

        netsh trace start capture=yes report=disabled traceFile=$fileName maxSize=$using:MaxSize correlation=disabled
    }

    $sessions = New-PSRemoteSession -IPAddress $IPAddress -Credential $Credential

    "Enabling tracing on {0}" -f ($IPAddress -join ', ') | Write-Verbose -Verbose
    Invoke-Command -Session $sessions -ScriptBlock $enableTracing
}

function Disable-TenantTracing {
    param (
        [Parameter(Mandatory = $true)]
        [String]$IPAddress,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    $disableTracing = {
        netsh trace stop
    }

    $sessions = New-PSRemoteSession -IPAddress $IPAddress -Credential $Credential
    Invoke-Command -Session $sessions -ScriptBlock $disableTracing
}

function Watch-ForFailure {

    param (
        [String]$LogName,
        [String]$Message
    )

    [Int]$Level = 2
    [DateTime]$Time = (Get-Date)

    while ($true) {
        $events = Get-WinEvent -FilterHashtable @{
            StartTime = $Time
            LogName = $LogName
            Level = $Level
        } -ErrorAction SilentlyContinue

        if ($events) {
            if ($events.Message -ilike "*$Message*") {
                return $true
            }
        }
    
        "Monitoring for failure..." | Write-Verbose -Verbose
        Start-Sleep -Seconds 5
    }
}

function New-PSRemoteSession {
    param (
        [String]$IPAddress,

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    # need to do string search as value returned is a single string
    $trustedHosts = Get-Item "WSMan:\LocalHost\Client\TrustedHosts"
    if($trustedHosts.Value -notlike "*$IPAddress*"){
        "{0} is missing from trusted hosts. Adding.." -f $IPAddress | Write-Verbose -Verbose
        Set-Item "WSMan:\localhost\Client\TrustedHosts" -Value $IPAddress -Concatenate -Force -PassThru
    }
    else {
        "{0} exists within trusted hosts." -f $IPAddress | Write-Verbose -Verbose
    }

    if($Credential -ne [System.Management.Automation.PSCredential]::Empty){
        $remoteSession = New-PSSession -ComputerName $IPAddress -Credential $Credential -SessionOption (New-PSSessionOption -Culture en-US -UICulture en-US) -ErrorAction Stop
    }
    else {
        $remoteSession = New-PSSession -ComputerName $IPAddress -SessionOption (New-PSSessionOption -Culture en-US -UICulture en-US) -ErrorAction Stop
    }

    "Created remote session {0} for {1}" -f $remoteSession.Id, $IPAddress | Write-Verbose -Verbose
    return $remoteSession
}

#### end functions ####

# enable network traces within the tenant virtual machines and then monitor for failure
Enable-TenantTracing -IPAddress $appVMIPAddress  -Credential $appVMCred -FilePath $tenantTraceFilePath -MaxSize 256
Enable-TenantTracing -IPAddress $sqlVMIPAddress  -Credential $sqlVMCred -FilePath $tenantTraceFilePath
$result = Invoke-Command -ComputerName $appVMIPAddress -Credential $appVMCred -ScriptBlock ${function:Watch-ForFailure} -ArgumentList ($LogName,$Message)

# once failure detected, we will want to disable tracing
if ($result) {
    "Repro of the issue identified. Disabling tracing" | Write-Verbose -Verbose

    Disable-TenantTracing -IPAddress $appVMIPAddress -Credential $appVMCred
    Disable-TenantTracing -IPAddress $sqlVMIPAddress  -Credential $sqlVMCred
}

# copy the files for MSFT CSS for analysis
$appVMSession = New-PSRemoteSession -IPAddress $appVMIPAddress -Credential $appVMCred
$sqlVMSession = New-PSRemoteSession -IPAddress $sqlVMIPAddress -Credential $sqlVMCred

if (-NOT (Test-Path -Path $outputDirectory)) {
    $null = New-Item -Path $outputDirectory -ItemType Directory -Force
}

Copy-Item -FromSession $appVMSession -Path "$tenantTraceFilePath\" -Include *.etl -Destination $outputDirectory -Recurse -Verbose
Copy-Item -FromSession $sqlVMSession -Path "$tenantTraceFilePath\" -Include *.etl -Destination $outputDirectory -Recurse -Verbose
