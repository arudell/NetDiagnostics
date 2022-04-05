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
        [System.Int32]$Port
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
                "Attempting to resolve {0} using DNS client server address {1}" -f $Endpoint, $dnsClientAddress | Write-Output
                $ipAddress = (Resolve-DnsName -Name $Endpoint -Type A -DnsOnly -Server $dnsClientAddress -ErrorAction SilentlyContinue).Ip4Address

                if ($null -eq $ipAddress) {
                    "Unable to return DNS results for {0} using {1}." -f $Endpoint, $dnsClientAddress | Write-Warning
                }
                else {
                    $ipArrayList += $ipAddress
                }
            }

            # if we returned no IP addresses from DNS, then advise user to investigate into DNS or try using an IP address and terminate
            if ($null -eq $ipArrayList) {
                "No IP addresses identified. Investigate further into DNS or run Debug-NetTCPConnection using IP address." | Write-Warning
                return
            }

            $Global:ProgressPreference = 'SilentlyContinue'
            foreach ($ip in $ipArrayList) {
                "Validating TCP connectivity to {0}:{1}" -f $ip, $Port | Write-Output
                $result = Test-NetConnection -ComputerName $ip -Port $Port -InformationLevel Detailed
            }
            $Global:ProgressPreference = 'Continue'
        }
    }
    catch {
        $_ | Write-Error
    }
}
