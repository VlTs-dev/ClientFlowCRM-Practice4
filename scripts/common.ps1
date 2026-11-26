function Get-ReleaseHash([string]$FilePath) {
    $resolvedFile = (Resolve-Path -LiteralPath $FilePath).ProviderPath
    $hasher = [Security.Cryptography.SHA256]::Create()
    $inputStream = [IO.File]::OpenRead($resolvedFile)
    try { return ([BitConverter]::ToString($hasher.ComputeHash($inputStream))).Replace('-', '').ToLowerInvariant() }
    finally { $inputStream.Dispose(); $hasher.Dispose() }
}
