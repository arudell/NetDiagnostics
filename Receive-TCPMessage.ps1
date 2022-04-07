Function Receive-TCPMessage {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, Position=0)]
        [ValidateNotNullOrEmpty()]
        [int]$Port = 3333
    )

    begin {
        "{0}: Creating TCP listener on port:{1}" -f (Get-Date).ToString(), $port| Write-Host -ForegroundColor:Cyan
        $endpoint = new-object System.Net.IPEndPoint([ipaddress]::any,$port)
        $listener = new-object System.Net.Sockets.TcpListener $EndPoint
        $listener.start()
    }
    process {
        while ($listener.Pending() -ne $true){
            Start-Sleep -Seconds 1
            "{0}: Waiting for connection... " -f (Get-Date).ToString() | Write-Host -ForegroundColor:Cyan
        }

        $client = $listener.AcceptTcpClient()
        "{0}: Accepted connection from {1}" -f (Get-Date).ToString(), $client.client.RemoteEndPoint | Write-Host -ForegroundColor:Green
        # Get a stream object for reading and writing
        $stream = $client.GetStream()
        $bytes = New-Object System.Byte[] 1024

        # Read data from stream and write it to host
        while (($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){
            $EncodedText = New-Object System.Text.ASCIIEncoding
            $data = $EncodedText.GetString($bytes,0, $i)
        }

        "{0}: Message: {1}" -f (Get-Date).ToString(), $data | Write-Host -ForegroundColor:Green -NoNewline
    }
    end {
        # Close TCP connection and stop listening
        "{0}: Removing TCP listener" -f (Get-Date).ToString() | Write-Host -ForegroundColor:Cyan
        $stream.close()
        $listener.stop()
    }
}
