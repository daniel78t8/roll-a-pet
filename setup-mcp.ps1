# Richtet Claude Code fuer Roblox Studio und Blender ein (Windows).
# Start:  powershell -ExecutionPolicy Bypass -File setup-mcp.ps1

$ErrorActionPreference = "Stop"

function Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "!!  $msg" -ForegroundColor Yellow }

# Entfernt einen alten Eintrag, damit "add" nicht an einem Duplikat scheitert
function Remove-Mcp($name) { try { claude mcp remove -s user $name 2>&1 | Out-Null } catch {} }

# --- Voraussetzungen -------------------------------------------------------

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw "Claude Code nicht gefunden. Erst installieren: npm install -g @anthropic-ai/claude-code"
}

if (-not (Get-Command uvx -ErrorAction SilentlyContinue)) {
    Info "Installiere uv (wird fuer blender-mcp gebraucht) ..."
    winget install --id astral-sh.uv -e --accept-source-agreements --accept-package-agreements
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
}

# --- Roblox Studio ---------------------------------------------------------

$robloxBat = Join-Path $env:LOCALAPPDATA "Roblox\mcp.bat"
if (Test-Path $robloxBat) {
    Info "Trage Roblox_Studio in Claude Code ein ..."
    Remove-Mcp "Roblox_Studio"
    claude mcp add -s user --transport stdio Roblox_Studio -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
} else {
    Warn "Kein $robloxBat gefunden. Installiere zuerst den Roblox Studio MCP-Server:"
    Warn "https://github.com/Roblox/studio-rust-mcp-server/releases  -> danach dieses Skript erneut starten."
}

# --- Blender ---------------------------------------------------------------

Info "Trage blender in Claude Code ein ..."
Remove-Mcp "blender"
claude mcp add -s user --transport stdio blender -- cmd /c uvx blender-mcp

Info "Lade Blender-Add-on herunter ..."
$addonFile = Join-Path $env:TEMP "blender_mcp_addon.py"
Invoke-WebRequest "https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py" -OutFile $addonFile

$blenderRoot = Join-Path $env:APPDATA "Blender Foundation\Blender"
$versions = @()
if (Test-Path $blenderRoot) {
    $versions = Get-ChildItem $blenderRoot -Directory | Where-Object { $_.Name -match '^\d+\.\d+$' }
}
if ($versions.Count -eq 0) {
    Warn "Kein Blender-Profilordner gefunden. Starte Blender einmal und fuehre das Skript erneut aus,"
    Warn "oder installiere $addonFile manuell (Edit > Preferences > Add-ons > Install)."
} else {
    foreach ($v in $versions) {
        $addonDir = Join-Path $v.FullName "scripts\addons"
        New-Item -ItemType Directory -Force -Path $addonDir | Out-Null
        Copy-Item $addonFile (Join-Path $addonDir "blender_mcp_addon.py") -Force
        Info "Add-on kopiert nach Blender $($v.Name)"
    }

    # Add-on aktivieren, falls blender.exe an der Standardstelle liegt
    $blenderExe = Get-ChildItem "C:\Program Files\Blender Foundation\*\blender.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($blenderExe) {
        Info "Aktiviere Add-on mit $($blenderExe.FullName) ..."
        & $blenderExe.FullName -b --python-expr "import bpy; bpy.ops.preferences.addon_enable(module='blender_mcp_addon'); bpy.ops.wm.save_userpref()" | Out-Null
    } else {
        Warn "blender.exe nicht gefunden - Add-on in Blender unter Edit > Preferences > Add-ons selbst anhaken."
    }
}

# --- Fertig ----------------------------------------------------------------

Write-Host ""
Info "Fertig. Jetzt noch:"
Write-Host "   1. Roblox Studio oeffnen (MCP-Plugin unter Plugins aktiv)"
Write-Host "   2. Blender oeffnen, Taste N, Tab 'BlenderMCP' -> Connect"
Write-Host "   3. 'claude' starten und mit /mcp pruefen"
