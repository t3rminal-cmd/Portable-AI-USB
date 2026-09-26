# ================================================================
# PORTABLE AI USB - WINDOWS LAUNCHER
# ================================================================
# Called by start-windows.bat. Starts the USB copy of Ollama and the
# AnythingLLM chat app with all their data kept on the USB drive, then
# shuts both down when you press Enter.
# Keep this file ASCII-only (Windows PowerShell 5.1).
# ================================================================

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host "==================================================="
Write-Host "    Launching Portable AI from USB..."
Write-Host "==================================================="
Write-Host ""

if (-not (Test-Path $OllamaExe) -or -not (Test-Path $AppExe)) {
    Write-Host "ERROR: The AI is not fully installed on this drive." -ForegroundColor Red
    if (-not (Test-Path $OllamaExe)) { Write-Host "  Missing: $OllamaExe" -ForegroundColor Red }
    if (-not (Test-Path $AppExe))    { Write-Host "  Missing: $AppExe" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Run install.bat first." -ForegroundColor Yellow
    exit 1
}

# -------------------------------------------------------
# Start the engine
# -------------------------------------------------------
Write-Host "Starting the AI engine..."
try {
    $OllamaProc = Start-UsbOllama
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$available = Get-OllamaModels
if (-not $available) {
    Write-Host ""
    Write-Host "WARNING: No AI models are installed yet. Run install.bat to add one." -ForegroundColor Yellow
}

# Default model: the first entry of installed-models.txt that the engine has.
$listed = Read-ModelList
$defaultModel = $null
foreach ($e in $listed) {
    if ($available -contains $e.Local) { $defaultModel = $e.Local; break }
}
if (-not $defaultModel -and $available) { $defaultModel = @($available)[0] }

# -------------------------------------------------------
# Point AnythingLLM at the USB engine
# -------------------------------------------------------
Update-AnythingLLMEnv -DefaultModel $defaultModel -Available $available

if ($available) {
    Write-Host ""
    Write-Host "Installed models:"
    foreach ($name in $available) {
        $entry = $listed | Where-Object { $_.Local -eq $name } | Select-Object -First 1
        if ($entry) {
            Write-Host "  - $($entry.Name) [$($entry.Label)]  ($name)"
        } else {
            Write-Host "  - $name"
        }
    }
    Write-Host ""
}

# -------------------------------------------------------
# Keep AnythingLLM's data on the USB
# -------------------------------------------------------
$env:STORAGE_DIR       = $DataDir
$env:APPDATA           = $DataDir
$env:LOCALAPPDATA      = $DataDir
$env:DISABLE_TELEMETRY = 'true'
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

# Electron caches absolute paths from the last PC. Clearing them fixes the
# "JavaScript error (ENOENT)" when the USB gets a different drive letter.
Remove-Item (Join-Path $DataDir 'config.json') -Force -ErrorAction SilentlyContinue
foreach ($cache in @('Cache', 'Code Cache', 'GPUCache')) {
    Remove-Item (Join-Path $DataDir $cache) -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Starting AnythingLLM..."
$AppProc = Start-Process -FilePath $AppExe -WorkingDirectory $AppDir -PassThru `
    -ArgumentList "--user-data-dir=`"$DataDir`""

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host "  SYSTEM ONLINE: Your AI is running from the USB!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Chat in the AnythingLLM window."
Write-Host "Keep THIS window open - it runs the AI engine."
Write-Host "To switch models: AnythingLLM > Settings > LLM."
Write-Host ""
Read-Host "Press Enter here to shut down the AI safely" | Out-Null

# -------------------------------------------------------
# Clean shutdown - only the processes started above
# -------------------------------------------------------
Write-Host "Shutting down..."
Stop-ProcessTree $AppProc -GraceSeconds 10
Stop-ProcessTree $OllamaProc
Write-Host "AI shut down. You can now safely eject the USB." -ForegroundColor Green
exit 0
