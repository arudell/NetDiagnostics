Function Send-TCPMessage {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [Parameter(Mandatory=$false, Position=1)]
        [int]$Port = 3333,

        [Parameter(Mandatory=$true, Position=2)]
        [string]$Message
    )

    begin {
        try {
            # Setup connection
            $IP = [System.Net.Dns]::GetHostAddresses($Destination)
            $Address = [System.Net.IPAddress]::Parse($IP)
            $Socket = New-Object System.Net.Sockets.TCPClient($Address,$Port)
        }
        catch {
            throw New-Object System.Exception($_)
        }
    }
    process {
        # Setup stream wrtier
        $Stream = $Socket.GetStream()
        $Writer = New-Object System.IO.StreamWriter($Stream)

        # Write message to stream
        $Message | ForEach-Object {
            $Writer.WriteLine($_)
            $Writer.Flush()
        }
    }
    end {
        # Close connection and stream
        $Stream.Close()
        $Socket.Close()
    }
}
