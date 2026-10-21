param(
    [string]$Godot = 'godot',
    [string]$OutputRoot = (Join-Path $env:TEMP 'crowns-mesh-tests')
)
# Agent: Codex-faisal. Keep logs and disposable saves, never use player data.
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$run = Join-Path $OutputRoot ([Guid]::NewGuid().ToString('N').Substring(0, 10))
New-Item -ItemType Directory -Force -Path $run | Out-Null
$previousAppData = $env:APPDATA
try {
    foreach ($case in 'lifetime', 'world') {
        $env:APPDATA = Join-Path $run $case
        if ($env:APPDATA.Length -gt 140) { throw 'Choose a shorter OutputRoot for Godot Windows saves.' }
        New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
        $log = Join-Path $run ($case + '.log')
        if ($case -eq 'lifetime') {
            & $Godot --headless --path $project --script tools/null_mesh_probe.gd -- --guard --free-first *> $log
            $expected = 'HEADLESS_MESH_TEST PASS'
        } else {
            & $Godot --headless --path $project --script tools/world_fingerprint.gd -- --play --seed=7 *> $log
            $expected = '(?m)^FINGERPRINT '
        }
        $exitCode = $LASTEXITCODE
        $text = Get-Content -LiteralPath $log -Raw
        if ($exitCode -ne 0 -or $text -match 'ERROR:' -or $text -notmatch $expected) {
            throw "Headless mesh $case failed (exit $exitCode); see $log"
        }
        Write-Output "PASS $case; zero engine/script errors; $log"
    }
} finally {
    $env:APPDATA = $previousAppData
}
