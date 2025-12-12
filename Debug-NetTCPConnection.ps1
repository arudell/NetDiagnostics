function Debug-NetTCPConnection {
    <#
        .SYNOPSIS
            Diagnostic script used to test core network connectivity to remote endpoint by validating DNS, TCP and TLS.
        .PARAMETER Endpoint
            The remote endpoint that you are attempting to create connection to.
        .PARAMETER Port
            The port number for the remote endpoint.
        .PARAMETER Credential
            Specify the remote credentials to access the remote endpoint. Used in conjuction with TlsEnabled:$true
        .EXAMPLE
            PS> Debug-NetTCPConnection -Endpoint login.microsoftonline.com -Port 443 -Credential (Get-Credential)
        .EXAMPLE
            PS> Debug-NetTCPConnection -Endpoint login.microsoftonline.com -Port 443
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [system.string]$Endpoint,

        [Parameter(Mandatory = $true)]
        [System.Int32]$Port,

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

    $ipArrayList = @()
    try {
        # check to see if we dealing with a URI string that was passed as endpoint
        if ($Endpoint.StartsWith("http")){
            [uri]$Endpoint = $Endpoint
            $TlsEnabled = $true

            $hostName = $Endpoint.Host
            if ($null -ieq $Port) {
                $Port = $Endpoint.Port
            }
        }
        else {
            $hostName = $Endpoint
        }

        # check to see if we dealing with an IP address, otherwise will need to get a list of IP address(es) from DNS to test
        if (Confirm-IpAddress -Value $hostName) {
            "Endpoint is an IP address: $hostName" | Write-Verbose
            $ipArrayList += $hostName
        }
        else {
            $dnsClientAddresses = (Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses | Sort-Object -Unique
            if ($null -eq $dnsClientAddresses) {
                throw "No DNS client server addresses defined on network interfaces. Investigate to determine why interfaces are not getting assigned a DNS server."
            }

            # check each dns client server address defined to ensure that each one is able to resolve the endpoint name
            foreach ($dnsClientAddress in $dnsClientAddresses) {
                "Attempting to resolve $hostName using DNS server $dnsClientAddress"  | Write-Verbose
                $ipAddress = (Resolve-DnsName -Name $hostName -Type A -DnsOnly -Server $dnsClientAddress -ErrorAction SilentlyContinue).Ip4Address

                if ($null -eq $ipAddress) {
                    Write-Host "✗ IP $($ipAddress) - DNS resolution failed using DNS server $dnsClientAddress" -ForegroundColor Red
                }
                else {
                    Write-Host "✓ IP $($ipAddress) - DNS resolution successful for $hostName" -ForegroundColor Green
                    $ipArrayList += $ipAddress
                }
            }

            # if we returned no IP addresses from DNS, then advise user to investigate into DNS or try using an IP address and terminate
            if ($null -eq $ipArrayList) {
                throw "No IP addresses identified. Investigate further into DNS or run Debug-NetTCPConnection using IP address."
            }
        }

        # now that we have the IP addresses to test against, lets first attempt to create a TCP connection to the remote endpoint
        # if this fails, then firewall policies may need to be investigated to see if there are any IP or TCP rules that would block the connection
        # this could be OS related firewalls or network firewall appliances
        $ipArrayList = $ipArrayList | Sort-Object -Unique
        foreach ($ip in $ipArrayList) {
            "Testing TCP connectivity to IP $ip on port $Port" | Write-Verbose
            $result = Test-NetConnection -ComputerName $ip -Port $Port -InformationLevel Detailed
            if ($result.TcpTestSucceeded -ne $true) {
                Write-Host "✗ IP $ip - TCP connection failed" -ForegroundColor Red
            }
            else {
                Write-Host "✓ IP $($ip):$($Port) - TCP connection successful" -ForegroundColor Green

                # if we specified the endpoint, then lets try to test TLS connection. this first requires that we had been able to establish TCP connectivity to the endpoint
                # this will ensure that the two endpoints can negotiate and mutally agree on the TLS certificate, ciphers and version that are being used
                if ($TlsEnabled) {
                    try {
                        $tcpClient = New-Object System.Net.Sockets.TcpClient($ip, $Port)
                        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false)
                        $sslStream.AuthenticateAsClient($hostname)

                        Write-Host "✓ IP $ip - TLS handshake successful" -ForegroundColor Green
                        Write-Host "`t`tCertificate: $($sslStream.RemoteCertificate.Subject)"
                        Write-Host "`t`tIssuer: $($sslStream.RemoteCertificate.Issuer)"
                    }
                    catch {
                        Write-Host "✗ IP $ip - TLS failed: $($_.Exception.Message)" -ForegroundColor Red
                    }
                    finally {
                        if ($sslStream) { $sslStream.Close() }
                        if ($tcpClient) { $tcpClient.Close() }
                    }
                }
            }
        }
    }
    catch {
        $_ | Write-Error
    }
}
