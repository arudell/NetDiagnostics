function Confirm-IpAddress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Value
    )

    $isIpAddress = ($Value -as [IPAddress]) -as [Bool]
    if ($isIpAddress) {
        return $true
    }
    else {
        return $false
    }
}

function Debug-NetTCPConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]$Endpoint,

        [Parameter(Mandatory = $true)]
        [System.Int32]$Port,

        [Parameter(Mandatory = $true)]
        [System.Boolean]$TlsEnabled,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    try {
        $ipArrayList = @()

        if (Confirm-IpAddress -Value $Endpoint) {
            $ipArrayList += $Endpoint
        }
        else {
            # get a list of dns client server addresses that are programmed for the network interfaces as we will want to test each one to ensure name resolution
            # if no server addresses defined, then throw warning and terminate
            $dnsClientAddresses = (Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses | Sort-Object -Unique
            if ($null -eq $dnsClientAddresses) {
                "No DNS client server addresses defined on network interfaces. Investigate to determine why interfaces are not getting assigned a DNS server." | Write-Warning
                return
            }

            # check each dns client server address defined to ensure that each one is able to resolve the endpoint name
            foreach ($dnsClientAddress in $dnsClientAddresses) {
                "Attempting to resolve {0} using DNS client server address {1}" -f $Endpoint, $dnsClientAddress | Write-Host -ForegroundColor:Cyan
                $ipAddress = (Resolve-DnsName -Name $Endpoint -Type A -DnsOnly -Server $dnsClientAddress -ErrorAction SilentlyContinue).Ip4Address

                if ($null -eq $ipAddress) {
                    "Unable to return DNS results for {0} using {1}." -f $Endpoint, $dnsClientAddress | Write-Warning
                }
                else {
                    "Successfully resolved {0} to {1}" -f $Endpoint, ($ipAddress -join ', ') | Write-Host -ForegroundColor:Green
                    $ipArrayList += $ipAddress
                }
            }

            # if we returned no IP addresses from DNS, then advise user to investigate into DNS or try using an IP address and terminate
            if ($null -eq $ipArrayList) {
                "No IP addresses identified. Investigate further into DNS or run Debug-NetTCPConnection using IP address." | Write-Warning
                return
            }

            $Global:ProgressPreference = 'SilentlyContinue'
            $ipArrayList = $ipArrayList | Sort-Object -Unique
            "Attempting to validate TCP connectivity to {0}" -f ($ipArrayList -join ', ') | Write-Host -ForegroundColor:Cyan
            foreach ($ip in $ipArrayList[0]) {
                "Testing TCP connectivity to {0}:{1}" -f $ip, $Port | function Confirm-IpAddress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Value
    )

    $isIpAddress = ($Value -as [IPAddress]) -as [Bool]
    if ($isIpAddress) {
        return $true
    }
    else {
        return $false
    }
}

function Debug-NetTCPConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]$Endpoint,

        [Parameter(Mandatory = $true)]
        [System.Int32]$Port,

        [Parameter(Mandatory = $true)]
        [System.Boolean]$TlsEnabled,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    try {
        $ipArrayList = @()

        if (Confirm-IpAddress -Value $Endpoint) {
            $ipArrayList += $Endpoint
        }
        else {
            # get a list of dns client server addresses that are programmed for the network interfaces as we will want to test each one to ensure name resolution
            # if no server addresses defined, then throw warning and terminate
            $dnsClientAddresses = (Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses | Sort-Object -Unique
            if ($null -eq $dnsClientAddresses) {
                "No DNS client server addresses defined on network interfaces. Investigate to determine why interfaces are not getting assigned a DNS server." | Write-Warning
                return
            }

            # check each dns client server address defined to ensure that each one is able to resolve the endpoint name
            foreach ($dnsClientAddress in $dnsClientAddresses) {
                "Attempting to resolve {0} using DNS client server address {1}" -f $Endpoint, $dnsClientAddress | Write-Host -ForegroundColor:Cyan
                $ipAddress = (Resolve-DnsName -Name $Endpoint -Type A -DnsOnly -Server $dnsClientAddress -ErrorAction SilentlyContinue).Ip4Address

                if ($null -eq $ipAddress) {
                    "Unable to return DNS results for {0} using {1}." -f $Endpoint, $dnsClientAddress | Write-Warning
                }
                else {
                    "Successfully resolved {0} to {1}" -f $Endpoint, ($ipAddress -join ', ') | Write-Host -ForegroundColor:Green
                    $ipArrayList += $ipAddress
                }
            }

            # if we returned no IP addresses from DNS, then advise user to investigate into DNS or try using an IP address and terminate
            if ($null -eq $ipArrayList) {
                "No IP addresses identified. Investigate further into DNS or run Debug-NetTCPConnection using IP address." | Write-Warning
                return
            }

            $Global:ProgressPreference = 'SilentlyContinue'
            $ipArrayList = $ipArrayList | Sort-Object -Unique
            "Attempting to validate TCP connectivity to {0}" -f ($ipArrayList -join ', ') | Write-Host -ForegroundColor:Cyan
            foreach ($ip in $ipArrayList[0]) {
                "Testing TCP connectivity to {0}:{1}" -f $ip, $Port | Write-Host -ForegroundColor:Cyan
                $result = Test-NetConnection -ComputerName $ip -Port $Port -InformationLevel Detailed
                if ($result.TcpTestSucceeded -ne $true) {
                    "Failed to establish TCP connection to {0}:{1}. Investigate further to validate appropriate firewall policies TCP traffic to specified endpoint and port." -f $ip, $Port | Write-Warning
                }
                else {
                    "Successfully established TCP connection to {0}:{1}" -f $ip, $Port | Write-Host -ForegroundColor:Green
                }
            }
            $Global:ProgressPreference = 'Continue'

            if ((-NOT (Confirm-IpAddress -Value $Endpoint)) -and $TlsEnabled) {
                $tlsVersions = @('Tls','Tls11','Tls12','Tls13')

                foreach ($version in $tlsVersions) {
                    "Configuring Windows PowerShell to use {0}" -f $version | Write-Host -ForegroundColor:Cyan
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::$version
                    [System.String]$uri = "https://{0}:{1}" -f $Endpoint, $Port

                    "Creating web request to {0}" -f $uri | Write-Host -ForegroundColor:Cyan
                    try {
                        if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
                            $webRequest = Invoke-WebRequest -Uri $uri -UseBasicParsing -Credential $Credential -TimeoutSec 20 -ErrorAction Stop
                        }
                        else {
                            $webRequest = Invoke-WebRequest -Uri $uri -UseBasicParsing -UseDefaultCredentials -TimeoutSec 20 -ErrorAction Stop
                        }

                        if ($webRequest) {
                            "Returned a status {0} from {1}" -f $webRequest.StatusDescription, $uri | Write-Host -ForegroundColor:Green
                        }
                    }
                    catch [System.Exception] {
                        switch -Wildcard ($_.Exception) {
                            "*The underlying connection was closed*" {
                                "{0} does not appear to be supported" -f $version | Write-Warning
                            }
                        }
                    }
                    catch {
                        throw $_
                    }
                }
            }
        }
    }
    catch {
        $_ | Write-Error
    }
}

                $result = Test-NetConnection -ComputerName $ip -Port $Port -InformationLevel Detailed
                if ($result.TcpTestSucceeded -ne $true) {
                    "Failed to establish TCP connection to {0}:{1}. Investigate further to validate appropriate firewall policies TCP traffic to specified endpoint and port." -f $ip, $Port | Write-Warning
                }
                else {
                    "Successfully established TCP connection to {0}:{1}" -f $ip, $Port | Write-Host -ForegroundColor:Green
                }
            }
            $Global:ProgressPreference = 'Continue'

            if ((-NOT (Confirm-IpAddress -Value $Endpoint)) -and $TlsEnabled) {
                $tlsVersions = @('Tls','Tls11','Tls12','Tls13')

                foreach ($version in $tlsVersions) {
                    "Configuring Windows PowerShell to use {0}" -f $version | Write-Host -ForegroundColor:Cyan
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::$version
                    [System.String]$uri = "https://{0}:{1}" -f $Endpoint, $Port

                    "Creating web request to {0}" -f $uri | Write-Host -ForegroundColor:Cyan
                    try {
                        if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
                            $webRequest = Invoke-WebRequest -Uri $uri -UseBasicParsing -Credential $Credential -TimeoutSec 20 -ErrorAction Stop
                        }
                        else {
                            $webRequest = Invoke-WebRequest -Uri $uri -UseBasicParsing -UseDefaultCredentials -TimeoutSec 20 -ErrorAction Stop
                        }

                        if ($webRequest) {
                            "Returned a status {0} from {1}" -f $webRequest.StatusDescription, $uri | Write-Host -ForegroundColor:Green
                        }
                    }
                    catch [System.Exception] {
                        switch -Wildcard ($_.Exception) {
                            "*The underlying connection was closed*" {
                                "{0} does not appear to be supported" -f $version | Write-Warning
                            }
                        }
                    }
                    catch {
                        throw $_
                    }
                }
            }
        }
    }
    catch {
        $_ | Write-Error
    }
}
