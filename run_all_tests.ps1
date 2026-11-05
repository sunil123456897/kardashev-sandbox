<#
.SYNOPSIS
    Master Automated Headless E2E Test Runner for Kardashev Sandbox: Crucible of Stars.
.DESCRIPTION
    Discovers and executes all project test suites in tests/ under Godot 4.7 headless mode.
    Wraps e:\Godot_Проекты\1\run_test_safe.ps1 to enforce 15s watchdog protection,
    immediate crash handling, and returns exit code 0 when all test suites pass with 0 failures (FAILED: 0).
.PARAMETER Filter
    Wildcard pattern to filter test filenames (e.g., "*milestone*", "*adversarial*", "*sandbox*").
.PARAMETER DefaultTimeoutMs
    Maximum duration in milliseconds permitted per test suite before watchdog kill (default: 15000 ms).
.PARAMETER CoreOnly
    If specified, runs only the Core Milestone and Master Integration suites.
.PARAMETER FailFast
    If specified, aborts the run immediately upon the first test suite failure.
#>

param(
    [string]$Filter = "*",
    [int]$DefaultTimeoutMs = 15000,
    [switch]$CoreOnly,
    [switch]$FailFast
)

$ErrorActionPreference = "Stop"

$proj = (Resolve-Path "E:\Godot*\1").Path
$safeRunner = Join-Path $proj "run_test_safe.ps1"

if (-not (Test-Path $safeRunner)) {
    Write-Host "[ERROR] run_test_safe.ps1 not found at $safeRunner" -ForegroundColor Red
    exit 1
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "=== MASTER E2E HEADLESS TEST RUNNER — KARDASHEV SANDBOX (GODOT 4.7) ===" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " Project Path: $proj"
Write-Host " Safe Runner:  $safeRunner"
Write-Host " Watchdog Cap: $DefaultTimeoutMs ms per suite"
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Test Suite Catalog
$CoreSuites = @(
    "tests/test_step1_registry.gd",
    "tests/test_step2_simulation.gd",
    "tests/test_milestone1_diplomacy.gd",
    "tests/test_milestone2_megastructures_and_laws.gd",
    "tests/test_milestone3_audiovisuals_and_ui.gd",
    "tests/test_milestone4_performance_and_stability.gd",
    "tests/test_worldbox_overhaul.gd",
    "tests/test_worldbox_complete_parity.gd",
    "tests/test_worldbox_supreme_blocks_abcd.gd",
    "tests/test_worldbox_authentic_pacing_and_visuals.gd",
    "tests/test_stage1_era_evolution.gd",
    "tests/test_stage2_naval_siege_warfare.gd",
    "tests/test_stage3_4_filter_and_god_feel.gd",
    "tests/test_worldbox_audit_fixes.gd",
    "tests/test_worldbox_visual_ui_parity.gd",
    "tests/test_sandbox_suite.gd"
)

$RobustnessSuites = @(
    "tests/test_audio_subsystem_verification.gd",
    "tests/adversarial_camera_stress.gd",
    "tests/adversarial_m2_reviewer2.gd",
    "tests/adversarial_m3_audio_stress.gd",
    "tests/adversarial_m3_r2_verification.gd",
    "tests/adversarial_m3_reviewer1.gd",
    "tests/adversarial_m3_reviewer2.gd",
    "tests/adversarial_m3_ui_boundaries.gd",
    "tests/stress_m1_challenger1.gd",
    "tests/stress_m1_challenger2.gd",
    "tests/stress_m2_challenger1.gd",
    "tests/stress_m2_challenger2.gd",
    "tests/stress_m4_warp_stability.gd"
)

$TestList = if ($CoreOnly) { $CoreSuites } else { $CoreSuites + $RobustnessSuites }

# Apply filter
if ($Filter -ne "*") {
    $TestList = $TestList | Where-Object { $_ -like $Filter -or [System.IO.Path]::GetFileName($_) -like $Filter }
}

if ($TestList.Count -eq 0) {
    Write-Host "[WARN] No test suites matched filter '$Filter'." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($TestList.Count) test suite(s) scheduled for execution.`n" -ForegroundColor DarkGray

# 2. Execution Loop
$results = @()
$totalStartTime = [System.Diagnostics.Stopwatch]::StartNew()
$passedCount = 0
$failedCount = 0

foreach ($testPath in $TestList) {
    $testFileName = [System.IO.Path]::GetFileName($testPath)
    $fullTestPath = Join-Path $proj $testPath
    if (-not (Test-Path $fullTestPath)) {
        Write-Host " [SKIP] $testPath (File does not exist yet)" -ForegroundColor Yellow
        continue
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $output = & powershell.exe -ExecutionPolicy Bypass -File "$safeRunner" -ScriptPath "$testPath" -TimeoutMs $DefaultTimeoutMs 2>&1
    $exitCode = $LASTEXITCODE
    $sw.Stop()

    $durationSec = [Math]::Round($sw.Elapsed.TotalSeconds, 2)

    $status = "PASS"
    $fgColor = "Green"
    if ($exitCode -eq 124) {
        $status = "TIMEOUT"
        $fgColor = "Red"
        $failedCount++
    } elseif ($exitCode -ne 0) {
        $status = "FAIL"
        $fgColor = "Red"
        $failedCount++
    } else {
        $passedCount++
    }

    $paddedDuration = ("{0:N2}s" -f $durationSec).PadLeft(7)
    $paddedStatus = ("[{0}]" -f $status).PadRight(10)
    Write-Host "$paddedStatus ($paddedDuration) $testPath" -ForegroundColor $fgColor

    if ($status -ne "PASS") {
        Write-Host "   --- FAILURE OUTPUT SNIPPET ---" -ForegroundColor DarkRed
        $output | Select-Object -Last 10 | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkYellow }
    }

    $results += [PSCustomObject]@{
        Suite    = $testFileName
        Status   = $status
        Duration = $durationSec
        ExitCode = $exitCode
    }

    if ($FailFast -and $status -ne "PASS") {
        Write-Host "`n[FAIL-FAST] Aborting test run after failure in $testFileName" -ForegroundColor Red
        break
    }
}

$totalStartTime.Stop()
$totalSec = [Math]::Round($totalStartTime.Elapsed.TotalSeconds, 2)

# 3. Final Summary Table
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "=== TEST SUITE EXECUTION SUMMARY ===" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

foreach ($r in $results) {
    $c = if ($r.Status -eq "PASS") { "Green" } else { "Red" }
    $stat = ("[{0}]" -f $r.Status).PadRight(10)
    $dur = ("{0:N2}s" -f $r.Duration).PadLeft(7)
    Write-Host " $stat ($dur) $($r.Suite)" -ForegroundColor $c
}

Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " Total Suites:  $($results.Count)"
Write-Host " Passed:        $passedCount" -ForegroundColor Green
Write-Host " Failed:        $failedCount" -ForegroundColor $(if ($failedCount -eq 0) { "Green" } else { "Red" })
Write-Host " Total Time:    $totalSec seconds"
Write-Host "================================================================================" -ForegroundColor Cyan

if ($failedCount -eq 0) {
    Write-Host ">>> ALL E2E TEST SUITES PASSED EMPIRICALLY (FAILED: 0) <<<" -ForegroundColor Green
    exit 0
} else {
    Write-Host ">>> E2E TEST RUN FAILED ($failedCount suite(s) failed) <<<" -ForegroundColor Red
    exit 1
}
