function Debug-NetTCPConnection {
    <#
        .SYNOPSIS
            Diagnostic script used to test core network connectivity to remote endpoint by validating DNS, TCP and TLS.
        .PARAMETER Endpoint
            The remote endpoint that you are attempting to create connection to.
        .PARAMETER Port
            The port number for the remote endpoint.
        .PARAMETER TlsEnabled
            Specify whether to test and validate TLS connectivity
        .PARAMETER Credential
            Specify the remote credentials to access the remote endpoint. Used in conjuction with TlsEnabled:$true
        .EXAMPLE
            PS> Debug-NetTCPConnection -Endpoint login.microsoftonline.com -Port 443 -TlsEnabled:$true
        .EXAMPLE
            PS> Debug-NetTCPConnection -Endpoint 20.190.155.16:443 -Port 443 -TlsEnabled:$true
        .EXAMPLE
            PS> Debug-NetTCPConnection -Endpoint login.microsoftonline.com -Port 443 -TlsEnabled:$true -Credential (Get-Credential)
        .EXAMPLE
            PS> Debug-NetTCPConnection -Endpoint login.microsoftonline.com -Port 443 -TlsEnabled:$false
    #>

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
                "[{0}] Attempting to resolve {0}" -f $dnsClientAddress, $Endpoint  | Write-Verbose
                $ipAddress = (Resolve-DnsName -Name $Endpoint -Type A -DnsOnly -Server $dnsClientAddress -ErrorAction SilentlyContinue).Ip4Address

                if ($null -eq $ipAddress) {
                    "[{0}] Unable to return DNS results for {0}." -f $dnsClientAddress, $Endpoint | Write-Warning
                }
                else {
                    "[{0}] Successfully resolved {1} to {2}" -f $dnsClientAddress, $Endpoint, ($ipAddress -join ', ') | Write-Host -ForegroundColor:Green
                    $ipArrayList += $ipAddress
                }
            }

            # if we returned no IP addresses from DNS, then advise user to investigate into DNS or try using an IP address and terminate
            if ($null -eq $ipArrayList) {
                "No IP addresses identified. Investigate further into DNS or run Debug-NetTCPConnection using IP address." | Write-Warning
                return
            }
        }

        # now that we have the IP addresses to test against, lets first attempt to create a TCP connection to the remote endpoint
        # if this fails, then firewall policies may need to be investigated to see if there are any IP or TCP rules that would block the connection
        # this could be OS related firewalls or network firewall appliances
        $Global:ProgressPreference = 'SilentlyContinue'
        $ipArrayList = $ipArrayList | Sort-Object -Unique
        "Attempting to validate TCP connectivity to {0}" -f ($ipArrayList -join ', ') | Write-Verbose
        foreach ($ip in $ipArrayList) {
            "[{0}:{1}] Testing TCP connectivity" -f $ip, $Port | Write-Verbose
            $result = Test-NetConnection -ComputerName $ip -Port $Port -InformationLevel Detailed
            if ($result.TcpTestSucceeded -ne $true) {
                "[{0}:{1}] Failed to establish TCP connection. Investigate further to validate appropriate firewall policies TCP traffic to specified endpoint and port." -f $ip, $Port | Write-Warning
            }
            else {
                "[{0}:{1}] Successfully established TCP connection." -f $ip, $Port | Write-Host -ForegroundColor:Green
            }
        }
        $Global:ProgressPreference = 'Continue'

        # if we specified the endpoint, then lets try to test TLS connection. this first requires that we had been able to establish TCP connectivity to the endpoint
        # this will ensure that the two endpoints can negotiate and mutally agree on the TLS certificate, ciphers and version that are being used
        if ((-NOT (Confirm-IpAddress -Value $Endpoint)) -and $TlsEnabled) {
            $tlsVersions = @('Tls','Tls11','Tls12','Tls13')

            foreach ($version in $tlsVersions) {
                "[{0}] Configuring Windows PowerShell to use {0}" -f $version | Write-Verbose
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::$version
                [System.String]$uri = "https://{0}:{1}" -f $Endpoint, $Port

                "[{0}] Creating web request to {1}" -f $version, $uri | Write-Verbose
                try {
                    if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
                        $webRequest = Invoke-WebRequest -Uri $uri -UseBasicParsing -Credential $Credential -TimeoutSec 20 -ErrorAction Stop
                    }
                    else {
                        $webRequest = Invoke-WebRequest -Uri $uri -UseBasicParsing -UseDefaultCredentials -TimeoutSec 20 -ErrorAction Stop
                    }

                    if ($webRequest) {
                        "[{0}] Returned a status {1} from {2}" -f $version, $webRequest.StatusDescription, $uri | Write-Host -ForegroundColor:Green
                    }
                }
                catch [System.Exception] {
                    switch -Wildcard ($_.Exception) {
                        "*The underlying connection was closed*" {
                            "[{0}] The underlying connection was closed. {0} does not appear to be supported." -f $version | Write-Warning
                        }
                    }
                }
                catch {
                    throw $_
                }
            }
        }
    }
    catch {
        $_ | Write-Error
    }
}
