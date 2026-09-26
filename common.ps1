# ================================================================
# PORTABLE AI USB - shared helpers
# ================================================================
# Dot-sourced by install-core.ps1 and start-core.ps1. Do not run directly.
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less
# scripts in the system code page.
# ================================================================

$UsbRoot    = $PSScriptRoot
$OllamaDir  = Join-Path $UsbRoot 'ollama'
$OllamaExe  = Join-Path $OllamaDir 'ollama.exe'
$OllamaData = Join-Path $OllamaDir 'data'
$OllamaHome = Join-Path $OllamaDir 'home'
$OllamaLog  = Join-Path $OllamaDir 'server.log'
$ModelsDir  = Join-Path $UsbRoot 'models'
$ModelList  = Join-Path $ModelsDir 'installed-models.txt'
$AppDir     = Join-Path $UsbRoot 'anythingllm'
$AppExe     = Join-Path $AppDir 'AnythingLLM.exe'
$DataDir    = Join-Path $UsbRoot 'anythingllm_data'
$EnvFile    = Join-Path $DataDir 'storage\.env'

# The USB copy of Ollama listens on its own port (not the default 11434),
# so it never collides with - or silently talks to - an Ollama that is
# already installed on the host PC.
$OllamaPort = 11435
$OllamaHost = "127.0.0.1:$OllamaPort"
$OllamaUrl  = "http://$OllamaHost"

# Windows PowerShell 5.1 defaults to TLS 1.0 for Invoke-RestMethod.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Write-Utf8NoBom {
    # Set-Content -Encoding UTF8 in PowerShell 5.1 writes a BOM, which ends up
    # glued to the first value when batch files or other tools read the file.
    param([string]$Path, [string]$Text)
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding $false))
}

function Get-ModelBaseName {
    param([string]$Name)
    return ($Name -replace ':latest$', '')
}

function Test-OllamaReady {
    try {
        $null = Invoke-RestMethod -UseBasicParsing -TimeoutSec 2 -Uri "$OllamaUrl/api/version"
        return $true
    } catch {
        return $false
    }
}

function Get-OllamaModels {
    # Names of the models the USB engine has imported, without the ":latest" tag.
    try {
        $r = Invoke-RestMethod -UseBasicParsing -TimeoutSec 10 -Uri "$OllamaUrl/api/tags"
        return @($r.models | ForEach-Object { Get-ModelBaseName $_.name })
    } catch {
        return @()
    }
}

function Get-PortOwner {
    # Returns @{Name; Path; Process} for whatever is listening on the port, or $null.
    param([int]$Port)
    $conn = $null
    try {
        $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop | Select-Object -First 1
    } catch {}
    if ($conn) {
        $p = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
        $path = $null
        try { $path = $p.Path } catch {}
        $name = "PID $($conn.OwningProcess)"
        if ($p) { $name = $p.ProcessName }
        return [pscustomobject]@{ Name = $name; Path = $path; Process = $p }
    }
    $client = New-Object Net.Sockets.TcpClient
    try {
        $client.Connect('127.0.0.1', $Port)
        return [pscustomobject]@{ Name = 'an unknown program'; Path = $null; Process = $null }
    } catch {
        return $null
    } finally {
        $client.Close()
    }
}

function Stop-ProcessTree {
    # Stops only the process we started (and its children) - never other
    # copies of Ollama or AnythingLLM that belong to the host PC.
    param($Process, [int]$GraceSeconds = 0)
    if (-not $Process) { return }
    try { if ($Process.HasExited) { return } } catch { return }
    if ($GraceSeconds -gt 0) {
        & taskkill.exe /PID $Process.Id /T 2>&1 | Out-Null
        try { if ($Process.WaitForExit($GraceSeconds * 1000)) { return } } catch {}
    }
    & taskkill.exe /PID $Process.Id /T /F 2>&1 | Out-Null
}

function Start-UsbOllama {
    # Starts the USB copy of Ollama and waits until it answers. Returns its
    # process; if this USB's engine is already running (for example after the
    # window was closed without shutting down), returns that one. Throws on failure.
    $env:OLLAMA_MODELS = $OllamaData
    $env:OLLAMA_HOST   = $OllamaHost
    New-Item -ItemType Directory -Force -Path $OllamaData, $OllamaHome | Out-Null

    $owner = Get-PortOwner $OllamaPort
    if ($owner) {
        if ($owner.Path -and ($owner.Path -ieq $OllamaExe) -and (Test-OllamaReady)) {
            Write-Host "  The USB AI engine is already running - reusing it." -ForegroundColor DarkGray
            return $owner.Process
        }
        throw "Port $OllamaPort is already in use by $($owner.Name). Close that program and try again."
    }

    # Ollama keeps its identity key under %USERPROFILE%\.ollama. Point that at
    # the USB for the engine process so nothing is written to the host PC.
    $savedProfile = $env:USERPROFILE
    $env:USERPROFILE = $OllamaHome
    try {
        $proc = Start-Process -FilePath $OllamaExe -ArgumentList 'serve' -NoNewWindow -PassThru `
            -RedirectStandardOutput (Join-Path $OllamaDir 'server-out.log') `
            -RedirectStandardError $OllamaLog
    } finally {
        $env:USERPROFILE = $savedProfile
    }

    # Ollama opens its port at once but only answers after it has checked the
    # graphics card, which loads several hundred MB of GPU libraries. From a
    # slow USB drive - with antivirus scanning each file the first time - that
    # can take minutes, so keep waiting while the engine is still running.
    Write-Host "  Waiting for the AI engine (the first start from a USB drive can take a few minutes)" -NoNewline
    $deadline = (Get-Date).AddMinutes(10)
    $nextDot = Get-Date
    while ((Get-Date) -lt $deadline) {
        if (Test-OllamaReady) {
            Write-Host " ready." -ForegroundColor Green
            return $proc
        }
        if ($proc.HasExited) { break }
        if ((Get-Date) -ge $nextDot) {
            Write-Host "." -NoNewline
            $nextDot = (Get-Date).AddSeconds(5)
        }
        Start-Sleep -Milliseconds 500
    }
    Write-Host ""

    if ($proc.HasExited) {
        $reason = "The AI engine stopped unexpectedly (exit code $($proc.ExitCode))."
    } else {
        $reason = "The AI engine did not answer within 10 minutes."
    }
    Stop-ProcessTree $proc
    $tail = Get-Content $OllamaLog -Tail 15 -ErrorAction SilentlyContinue
    throw ("$reason Last lines of ollama\server.log:`n" + ($tail -join "`n"))
}

function Get-EnvValue {
    param([string[]]$Lines, [string]$Key)
    foreach ($l in $Lines) {
        if ($l -match ('^\s*' + [regex]::Escape($Key) + '\s*=\s*(.*)$')) {
            return $Matches[1].Trim().Trim("'").Trim('"')
        }
    }
    return $null
}

function Set-EnvValues {
    # Updates only the given keys in AnythingLLM's .env and keeps everything
    # else the user configured. Values are written quoted, like AnythingLLM does.
    param([string]$Path, [System.Collections.IDictionary]$Values)
    $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Path $Path) {
        foreach ($l in [IO.File]::ReadAllLines($Path)) { $lines.Add($l) }
    }
    foreach ($key in $Values.Keys) {
        $newLine = "$key='$($Values[$key])'"
        $found = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match ('^\s*' + [regex]::Escape($key) + '\s*=')) {
                $lines[$i] = $newLine
                $found = $true
            }
        }
        if (-not $found) { $lines.Add($newLine) }
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    Write-Utf8NoBom $Path (($lines -join "`r`n") + "`r`n")
}

function Update-AnythingLLMEnv {
    # Points AnythingLLM at the USB engine, keeps the user's other settings,
    # and turns off AnythingLLM's anonymous telemetry.
    param([string]$DefaultModel, [string[]]$Available = @())
    $lines = @()
    if (Test-Path $EnvFile) { $lines = [IO.File]::ReadAllLines($EnvFile) }

    $provider = Get-EnvValue $lines 'LLM_PROVIDER'
    $values = [ordered]@{ DISABLE_TELEMETRY = 'true' }

    if (-not $provider -or $provider -eq 'anythingllm_ollama') {
        $values['LLM_PROVIDER'] = 'ollama'
        $values['OLLAMA_BASE_PATH'] = $OllamaUrl
        if ($DefaultModel) { $values['OLLAMA_MODEL_PREF'] = $DefaultModel }
        $values['OLLAMA_MODEL_TOKEN_LIMIT'] = '4096'
        if (-not (Get-EnvValue $lines 'EMBEDDING_ENGINE')) { $values['EMBEDDING_ENGINE'] = 'native' }
        if (-not (Get-EnvValue $lines 'VECTOR_DB')) { $values['VECTOR_DB'] = 'lancedb' }
    } elseif ($provider -eq 'ollama') {
        $values['OLLAMA_BASE_PATH'] = $OllamaUrl
        $pref = Get-EnvValue $lines 'OLLAMA_MODEL_PREF'
        $prefMissing = (-not $pref) -or ($Available.Count -gt 0 -and $Available -notcontains (Get-ModelBaseName $pref))
        if ($prefMissing -and $DefaultModel) { $values['OLLAMA_MODEL_PREF'] = $DefaultModel }
    } else {
        Write-Host "  NOTE: AnythingLLM is set to use '$provider' instead of the USB engine." -ForegroundColor Yellow
        Write-Host "        Your chats may be sent over the internet. To keep them private," -ForegroundColor Yellow
        Write-Host "        choose Ollama in AnythingLLM under Settings > LLM." -ForegroundColor Yellow
    }

    Set-EnvValues $EnvFile $values
}

function Read-ModelList {
    # Entries from models\installed-models.txt as objects with Local, Name, Label.
    $result = @()
    if (-not (Test-Path $ModelList)) { return $result }
    foreach ($line in [IO.File]::ReadAllLines($ModelList)) {
        $parts = $line.Split('|')
        if ($parts.Count -ge 1 -and $parts[0].Trim()) {
            $name = $parts[0].Trim()
            if ($parts.Count -ge 2) { $name = $parts[1] }
            $label = ''
            if ($parts.Count -ge 3) { $label = $parts[2] }
            $result += [pscustomobject]@{ Local = $parts[0].Trim(); Name = $name; Label = $label }
        }
    }
    return $result
}
