param([string]$Root, [int]$Port=9419)
$ErrorActionPreference = 'Stop'
$base = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
$listener.Start()
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 4096, $true)
            $line = $reader.ReadLine()
            if (-not $line) { continue }
            $pieces = $line.Split(' ')
            $method = $pieces[0]
            $urlPath = [Uri]::UnescapeDataString(($pieces[1] -split '\?')[0]).TrimStart('/')
            while ($reader.ReadLine()) {}
            $path = [IO.Path]::GetFullPath((Join-Path $base $urlPath))
            $valid = $path.StartsWith($base, [StringComparison]::OrdinalIgnoreCase) -and ($method -eq 'GET' -or $method -eq 'HEAD') -and (Test-Path -LiteralPath $path -PathType Leaf)
            if ($valid) {
                $body = [IO.File]::ReadAllBytes($path)
                $status = '200 OK'
            } else {
                $body = [Text.Encoding]::ASCII.GetBytes('Not found')
                $status = '404 Not Found'
            }
            $header = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: application/octet-stream`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n")
            $stream.Write($header, 0, $header.Length)
            if ($method -ne 'HEAD') { $stream.Write($body, 0, $body.Length) }
            $stream.Flush()
        } catch {
            Write-Output $_.Exception.Message
        } finally { $client.Dispose() }
    }
} finally { $listener.Stop() }
