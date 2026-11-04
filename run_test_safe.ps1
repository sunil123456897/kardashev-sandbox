param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptPath,
    [int]$TimeoutMs = 15000
)
$ErrorActionPreference = "Stop"
$godot = (Resolve-Path "C:\Users\vanya\Desktop\*\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe").Path
$proj = (Resolve-Path "E:\Godot*\1").Path
$outFile = Join-Path $env:TEMP ("godot_out_" + [guid]::NewGuid().ToString() + ".log")
$errFile = Join-Path $env:TEMP ("godot_err_" + [guid]::NewGuid().ToString() + ".log")

$p = Start-Process -FilePath $godot -ArgumentList @("--headless", "--path", $proj, "-s", $ScriptPath) -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru -WindowStyle Hidden
try {
    $elapsed = 0
    $killedOnError = $false
    $timedOut = $false
    while (-not $p.WaitForExit(250)) {
        $elapsed += 250
        if (Test-Path $errFile) {
            $errSnap = Get-Content $errFile -Raw -ErrorAction SilentlyContinue
            if ($errSnap -match "Assertion failed|Parse Error|Compile Error|Invalid access|Invalid call|Cannot call method") {
                Start-Sleep -Milliseconds 200
                try { $p.Kill() } catch {}
                $killedOnError = $true
                break
            }
        }
        if ($elapsed -ge $TimeoutMs) {
            try { $p.Kill() } catch {}
            $timedOut = $true
            break
        }
    }
    if ($timedOut) {
        Write-Host "=== TIMEOUT ($TimeoutMs ms) EXCEEDED — PROCESS KILLED ===" -ForegroundColor Red
    }
    if ($killedOnError) {
        Write-Host "=== FATAL SCRIPT/ASSERTION ERROR DETECTED — PROCESS KILLED IMMEDIATELY ===" -ForegroundColor Red
    }
    if (Test-Path $outFile) { Get-Content $outFile -Raw }
    if (Test-Path $errFile) {
        $errContent = Get-Content $errFile -Raw
        if ($errContent) { Write-Host "=== STDERR ===" -ForegroundColor Yellow; Write-Host $errContent }
    }
    if ($timedOut) { exit 124 }
    if ($killedOnError) { exit 1 }
    exit $p.ExitCode
} finally {
    if ($null -ne $p -and -not $p.HasExited) {
        try { $p.Kill() } catch {}
    }
    Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
}
