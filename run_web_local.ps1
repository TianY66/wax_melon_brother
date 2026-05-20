param(
    [string]$GodotExe = "D:\Godot\Godot_v4.6.2-stable_win64_console.exe",
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

function Test-PortAvailable {
    param([int]$CandidatePort)

    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $CandidatePort)
        $listener.Start()
        return $true
    } catch {
        return $false
    } finally {
        if ($null -ne $listener) {
            $listener.Stop()
        }
    }
}

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot console executable not found: $GodotExe"
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python is required to serve the exported Web build."
}

$repoRoot = $PSScriptRoot
$distDir = Join-Path $repoRoot "dist\\web"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

Write-Host "Exporting Web build to $distDir ..."
& $GodotExe --headless --path $repoRoot --export-release "Web" "dist/web/index.html"
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed."
}

$servePort = $Port
while (-not (Test-PortAvailable -CandidatePort $servePort)) {
    $servePort++
}

Write-Host "Serving Web build at http://127.0.0.1:$servePort/index.html"
Write-Host "Press Ctrl+C to stop the local server."

Push-Location $distDir
try {
    python -m http.server $servePort --bind 127.0.0.1
} finally {
    Pop-Location
}
