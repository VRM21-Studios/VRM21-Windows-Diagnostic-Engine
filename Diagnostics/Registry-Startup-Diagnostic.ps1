# =====================================================================
# REGISTRY STARTUP DIAGNOSTIC
# Version : 1.1
# Mode    : Read-Only Audit
# Purpose : Detect active, stale, and optional startup entries
# =====================================================================

Write-Host "===================================================="
Write-Host " REGISTRY STARTUP DIAGNOSTIC"
Write-Host "====================================================`n"


# =====================================================================
# REGISTRY RUN KEYS
# =====================================================================
$RunKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
)


# Properties automatically added by PowerShell.
# These properties must not be treated as startup entries.
$IgnoreProps = @(
    "PSPath",
    "PSParentPath",
    "PSChildName",
    "PSDrive",
    "PSProvider"
)

$Results = @()


# =====================================================================
# STARTUP ENTRY ANALYSIS
# =====================================================================
foreach ($Key in $RunKeys) {

    if (-not (Test-Path $Key)) {
        continue
    }

    Write-Host "Scanning $Key" -ForegroundColor Cyan

    $Item = Get-ItemProperty $Key

    $Item |
        Get-Member -MemberType NoteProperty |
        Where-Object {
            $IgnoreProps -notcontains $_.Name
        } |
        ForEach-Object {

            $Name = $_.Name
            $Command = $Item.$Name


            # ---------------------------------------------------------
            # Extract executable path using best-effort pattern matching.
            # ---------------------------------------------------------
            $ExePath = $null

            if ($Command -match '"([^"]+\.exe)"') {
                $ExePath = $Matches[1]
            }
            elseif ($Command -match '^([^\s]+\.exe)') {
                $ExePath = $Matches[1]
            }

            $Exists = if ($ExePath) {
                Test-Path $ExePath
            }
            else {
                $false
            }


            # ---------------------------------------------------------
            # Classify the startup entry.
            # ---------------------------------------------------------
            $Class =
                if (-not $ExePath) {
                    "UNKNOWN"
                }
                elseif (-not $Exists) {
                    "STALE_ENTRY"
                }
                elseif ($ExePath -match "\\Windows\\System32") {
                    "SYSTEM_CORE"
                }
                elseif ($ExePath -match "Program Files") {
                    "ACTIVE"
                }
                else {
                    "USER_OPTIONAL"
                }


            $Results += [PSCustomObject]@{
                Location = $Key
                Name     = $Name
                Class    = $Class
                Exists   = $Exists
                Path     = $ExePath
                Command  = $Command
            }
        }

    Write-Host ""
}


# =====================================================================
# OUTPUT
# =====================================================================

if ($Results.Count -eq 0) {
    Write-Host "No startup entries found." -ForegroundColor Green
}
else {
    Write-Host "RESULTS:`n"

    $Results |
        Sort-Object Class, Name |
        Format-Table Location, Name, Class, Exists -AutoSize
}


Write-Host "`nSUMMARY:"

$Results |
    Group-Object Class |
    Sort-Object Name |
    ForEach-Object {
        Write-Host ("  {0,-15}: {1}" -f $_.Name, $_.Count)
    }


Write-Host "`n===================================================="
Write-Host " REGISTRY STARTUP DIAGNOSTIC COMPLETE"
Write-Host "===================================================="


# =====================================================================
# JSON EXPORT FOR PYTHON / LLM INTEGRATION
# =====================================================================
$SummaryStats = @{}

$Results |
    Group-Object Class |
    ForEach-Object {
        $SummaryStats[$_.Name] = $_.Count
    }


$DiagnosticResult = [ordered]@{
    "TotalEntries" = $Results.Count
    "Summary"      = $SummaryStats
    "StaleEntries" = (
        $Results |
            Where-Object {
                $_.Class -eq "STALE_ENTRY"
            } |
            Select-Object Name, Command
    )
    "UserOptional" = (
        $Results |
            Where-Object {
                $_.Class -eq "USER_OPTIONAL"
            } |
            Select-Object Name, Command
    )
}


# Convert the diagnostic result to a compact JSON string.
$JsonOutput = $DiagnosticResult |
    ConvertTo-Json -Depth 3 -Compress

Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"
