# ======================================================================
# Cache & Recycle Bin Diagnostic
# Version : 1.0
# Mode    : Read-Only Audit (No Auto Delete)
# Purpose : Analyze system cache, temp files, and recycle bin usage
# ======================================================================

Write-Host "===================================================="
Write-Host " CACHE & RECYCLE BIN DIAGNOSTIC"
Write-Host "====================================================`n"

# ------------------------------------------------------
# Helper: Format Size
# ------------------------------------------------------
function Format-Size {
    param([Int64]$Bytes)

    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }

    return "$Bytes B"
}

# ------------------------------------------------------
# Paths to Check
# ------------------------------------------------------
$TempUser   = $env:TEMP
$TempSystem = "C:\Windows\Temp"
$Prefetch   = "C:\Windows\Prefetch"
$EdgeCache  = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
$ChromeCache= "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"

$Paths = @(
    @{ Name="User Temp";    Path=$TempUser },
    @{ Name="System Temp";  Path=$TempSystem },
    @{ Name="Prefetch";     Path=$Prefetch },
    @{ Name="Edge Cache";   Path=$EdgeCache },
    @{ Name="Chrome Cache"; Path=$ChromeCache }
)

# ------------------------------------------------------
# Analyze Folder
# ------------------------------------------------------
function Analyze-Folder {
    param(
        [string]$Name,
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-Host "[$Name]"
        Write-Host " Path : $Path"
        Write-Host " Status : Not Found`n"
        return @{
            Name=$Name
            Exists=$false
            Files=0
            Size=0
        }
    }

    try {
        $Files = Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue
        $Count = $Files.Count
        $Size  = ($Files | Measure-Object Length -Sum).Sum
    }
    catch {
        $Count = 0
        $Size  = 0
    }

    Write-Host "[$Name]"
    Write-Host " Path  : $Path"
    Write-Host " Files : $Count"
    Write-Host " Size  : $(Format-Size $Size)`n"

    return @{
        Name=$Name
        Exists=$true
        Files=$Count
        Size=$Size
    }
}

# ------------------------------------------------------
# Analyze Caches
# ------------------------------------------------------
Write-Host "----------------------------------------------------"
Write-Host " CACHE ANALYSIS"
Write-Host "----------------------------------------------------`n"

$Results = @()

foreach ($item in $Paths) {
    $res = Analyze-Folder -Name $item.Name -Path $item.Path
    $Results += $res
}

# ------------------------------------------------------
# Recycle Bin Analysis
# ------------------------------------------------------
Write-Host "----------------------------------------------------"
Write-Host " RECYCLE BIN ANALYSIS"
Write-Host "----------------------------------------------------`n"

$RecycleSize = 0
$RecycleCount = 0

try {
    $Shell = New-Object -ComObject Shell.Application
    $Recycle = $Shell.Namespace(0xA)

    if ($Recycle) {
        $Items = $Recycle.Items()
        $RecycleCount = $Items.Count

        foreach ($item in $Items) {
            $RecycleSize += $item.Size
        }
    }
}
catch {
    Write-Host "⚠ Failed to access Recycle Bin."
}

Write-Host "Items : $RecycleCount"
Write-Host "Size  : $(Format-Size $RecycleSize)`n"

# ------------------------------------------------------
# Summary
# ------------------------------------------------------
Write-Host "===================================================="
Write-Host " CACHE & RECYCLE BIN SUMMARY"
Write-Host "===================================================="

$TotalCache = ($Results | ForEach-Object { $_["Size"] } | Measure-Object -Sum).Sum
$TotalWaste = $TotalCache + $RecycleSize

Write-Host "Total Cache Size   : $(Format-Size $TotalCache)"
Write-Host "Recycle Bin Size   : $(Format-Size $RecycleSize)"
Write-Host "Potential Cleanup  : $(Format-Size $TotalWaste)`n"

# ------------------------------------------------------
# Recommendation
# ------------------------------------------------------
Write-Host "Recommendations:"

if ($TotalWaste -lt 500MB) {
    Write-Host " ✔ System is clean. No urgent cleanup needed."
}
elseif ($TotalWaste -lt 2GB) {
    Write-Host " ⚠ Moderate cache buildup. Cleanup recommended."
}
else {
    Write-Host " ❗ Large cache detected. Cleanup strongly recommended."
}

Write-Host ""
Write-Host "Note:"
Write-Host "- This module does NOT delete files."
Write-Host "- Use Disk Cleanup / Storage Sense for safe cleanup."
Write-Host "- Manual deletion is possible but not recommended for Prefetch."

Write-Host "`n===================================================="
Write-Host " CACHE & RECYCLE BIN DIAGNOSTIC COMPLETE"
Write-Host "===================================================="

# =====================================================================
# JSON EXPORT FOR PYTHON / LLM INTEGRATION
# =====================================================================
$DiagnosticStatus = if ($TotalWaste -lt 500MB) { "Clean" } 
                    elseif ($TotalWaste -lt 2GB) { "Moderate" } 
                    else { "Large" }

$DiagnosticResult = [ordered]@{
    "TotalCacheBytes"     = $TotalCache
    "RecycleBinBytes"     = $RecycleSize
    "TotalWasteBytes"     = $TotalWaste
    "TotalWasteFormatted" = "$(Format-Size $TotalWaste)"
    "Status"              = $DiagnosticStatus
    "PathsScanned"        = $Results
}

# Convert to JSON and output it as a pure string
$JsonOutput = $DiagnosticResult | ConvertTo-Json -Depth 4 -Compress
Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"