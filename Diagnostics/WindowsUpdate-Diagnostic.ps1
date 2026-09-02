# ======================================================================
# Windows Update Log Diagnostic
# Version : 1.0
# Mode    : Read-Only Audit
# Purpose : Generate and summarize WindowsUpdate.log
# ======================================================================

Write-Host "===================================================="
Write-Host " WINDOWS UPDATE LOG DIAGNOSTIC"
Write-Host "====================================================`n"

# ------------------------------------------------------
# Require Administrator Privileges
# ------------------------------------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "❌ Administrator privileges required for this module."
    Write-Host "   Please re-run SystemAudit.py from an elevated shell."
    return
}

$Desktop = [Environment]::GetFolderPath("Desktop")
$LogPath = Join-Path $Desktop "WindowsUpdate.log"

# ------------------------------------------------------
# Generate WindowsUpdate.log if it does not exist
# ------------------------------------------------------
if (-not (Test-Path $LogPath)) {
    Write-Host "WindowsUpdate.log not found."
    Write-Host "Generating log from ETW (this may take a moment)...`n"

    try {
        Get-WindowsUpdateLog | Out-Null
    }
    catch {
        Write-Host "❌ Failed to generate WindowsUpdate.log"
        Write-Host "   Please run this script as Administrator."
        return
    }
}

if (-not (Test-Path $LogPath)) {
    Write-Host "❌ WindowsUpdate.log was not found after the generation attempt."
    return
}

# ------------------------------------------------------
# Parse Log
# ------------------------------------------------------
$Keywords = @(
    "error",
    "fail",
    "warning",
    "success",
    "update",
    "restart"
)

$MaxLines = 200
$TotalLines = 0
$Matched = 0

Write-Host "Parsing WindowsUpdate.log..."
Write-Host "Path : $LogPath`n"

$FileInfo = Get-Item $LogPath
if ($FileInfo.Length -lt 1024) {
    Write-Host "⚠ WindowsUpdate.log is unusually small ($($FileInfo.Length) bytes)."
    Write-Host "  The log may be empty or may not have been generated correctly."
    Write-Host "  Try deleting the file and running this module again as Administrator."
    return
}

Get-Content $LogPath -ErrorAction SilentlyContinue | ForEach-Object {

    $TotalLines++

    foreach ($key in $Keywords) {
        if ($_.ToLower().Contains($key)) {
            $Matched++

            if ($Matched -le $MaxLines) {
                Write-Host ("{0:000}. {1}" -f $Matched, $_)
            }

            break
        }
    }
}

# ------------------------------------------------------
# Summary
# ------------------------------------------------------
Write-Host "`n===================================================="
Write-Host " WINDOWS UPDATE LOG SUMMARY"
Write-Host "===================================================="
Write-Host "Total lines scanned : $TotalLines"
Write-Host "Matched entries     : $Matched"

if ($Matched -gt $MaxLines) {
    Write-Host ("({0} additional matching lines not shown)" -f ($Matched - $MaxLines))
}

Write-Host ""
Write-Host "Notes:"
Write-Host "- The log is generated from ETW on supported Windows versions."
Write-Host "- Matching entries may help identify Windows Update-related issues."
Write-Host "- This module performs a read-only audit."

Write-Host "`n===================================================="
Write-Host " WINDOWS UPDATE LOG DIAGNOSTIC COMPLETE"
Write-Host "===================================================="

# ======================================================================
# JSON EXPORT FOR PYTHON / LLM INTEGRATION
# ======================================================================
$DiagnosticResult = [ordered]@{
    "IsAdmin"           = $IsAdmin
    "LogGenerated"      = (Test-Path $LogPath)
    "TotalLinesScanned" = $TotalLines
    "MatchedLinesCount" = $Matched
    "MaxLinesReached"   = ($Matched -gt $MaxLines)
}

# Convert the diagnostic result to a compact JSON string.
if ($IsAdmin) {
    $JsonOutput = $DiagnosticResult | ConvertTo-Json -Depth 3 -Compress
    Write-Output "---JSON_START---"
    Write-Output $JsonOutput
    Write-Output "---JSON_END---"
}
