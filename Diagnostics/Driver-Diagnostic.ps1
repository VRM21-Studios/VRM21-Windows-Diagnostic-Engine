# ======================================================================
# Driver Detailed Diagnostic
# Version : 1.0
# Mode    : Read-Only Audit
# Purpose : Analyze installed drivers, device status, driver versions,
#           driver files, and critical driver categories
# ======================================================================

Write-Host "===================================================="
Write-Host " DRIVER DETAILED DIAGNOSTIC"
Write-Host "====================================================`n"

$DriverScore = 100
$DriverIssues = @()
$DriverWarnings = @()

# ======================================================================
# 1. DRIVER INVENTORY SUMMARY
# ======================================================================
Write-Host "[1] DRIVER INVENTORY SUMMARY" -ForegroundColor Yellow

try {
    $AllDrivers = Get-CimInstance Win32_PnPSignedDriver
    $Total = $AllDrivers.Count

    Write-Host "Total Installed Drivers : $Total" -ForegroundColor Cyan

    $Unsigned = $AllDrivers | Where-Object {
        $_.IsSigned -eq $false
    }

    $UnsignedCount = $Unsigned.Count

    Write-Host "Unsigned Drivers        : $UnsignedCount" `
        -ForegroundColor $(
            if ($UnsignedCount -eq 0) {
                "Green"
            } elseif ($UnsignedCount -lt 10) {
                "Yellow"
            } else {
                "Red"
            }
        )

    if ($UnsignedCount -gt 10) {
        $DriverIssues += "Too many unsigned drivers"
        $DriverScore -= 20
    } elseif ($UnsignedCount -gt 0) {
        $DriverWarnings += "Some drivers are unsigned"
        $DriverScore -= 10
    }

} catch {
    Write-Host "Driver enumeration failed." -ForegroundColor Red
    $DriverScore -= 20
}

# ======================================================================
# 2. UNSIGNED DRIVERS
# ======================================================================
Write-Host "`n[2] UNSIGNED DRIVERS" -ForegroundColor Yellow

if ($UnsignedCount -gt 0) {
    $Unsigned |
        Select-Object DeviceName, DriverVersion, DriverProviderName, Manufacturer, Path |
        Format-Table -AutoSize
} else {
    Write-Host "No unsigned drivers detected." -ForegroundColor Green
}

# ======================================================================
# 3. OUTDATED DRIVER ANALYSIS
# ======================================================================
Write-Host "`n[3] OUTDATED DRIVER ANALYSIS" -ForegroundColor Yellow

$OldDrivers = $AllDrivers | Where-Object {
    $_.DriverDate -lt (Get-Date).AddYears(-5)
}

if ($OldDrivers.Count -gt 0) {
    Write-Host "Drivers older than 5 years: $($OldDrivers.Count)" `
        -ForegroundColor Yellow

    $OldDrivers |
        Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate |
        Sort-Object DriverDate |
        Format-Table -AutoSize

    if ($OldDrivers.Count -gt 20) {
        $DriverScore -= 20
        $DriverIssues += "Large number of very old drivers detected"
    } else {
        $DriverScore -= 10
        $DriverWarnings += "Some drivers are outdated"
    }
} else {
    Write-Host "No outdated drivers detected." -ForegroundColor Green
}

# ======================================================================
# 4. DEVICE PROBLEM REPORT
# ======================================================================
Write-Host "`n[4] DEVICE PROBLEM REPORT (DEVICE MANAGER STATUS)" `
    -ForegroundColor Yellow

try {
    $ProblemDevices = Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.ConfigManagerErrorCode -ne 0
    }

    if ($ProblemDevices.Count -gt 0) {
        Write-Host "Devices with errors: $($ProblemDevices.Count)" `
            -ForegroundColor Red

        $ProblemDevices |
            Select-Object Name, Manufacturer, ConfigManagerErrorCode |
            Format-Table -AutoSize

        $DriverScore -= 25
        $DriverIssues += "Devices with error codes detected"
    } else {
        Write-Host "No device problems detected." -ForegroundColor Green
    }
} catch {
    Write-Host "Unable to retrieve the device problem list." `
        -ForegroundColor Gray
}

# ======================================================================
# 5. CRITICAL DRIVER CATEGORY CHECK
# ======================================================================
Write-Host "`n[5] CRITICAL DRIVER CATEGORY CHECK" -ForegroundColor Yellow

# ----------------------------------------------------------------------
# 5a. GPU DRIVERS
# ----------------------------------------------------------------------
Write-Host "`n[5a] GPU DRIVERS" -ForegroundColor Cyan

$GPUDrivers = $AllDrivers | Where-Object {
    $_.DeviceName -match "NVIDIA|AMD|Intel" -and
    $_.DriverProviderName -match "NVIDIA|AMD|Intel"
}

if ($GPUDrivers.Count -gt 0) {
    $GPUDrivers |
        Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate |
        Format-Table -AutoSize

    foreach ($GPU in $GPUDrivers) {
        if ($GPU.DriverDate -lt (Get-Date).AddYears(-3)) {
            Write-Host "  WARNING: GPU driver outdated ($($GPU.DeviceName))" `
                -ForegroundColor Yellow

            $DriverWarnings += "Outdated GPU driver: $($GPU.DeviceName)"
            $DriverScore -= 10
        }
    }
} else {
    Write-Host "No GPU drivers detected. This may be unusual." `
        -ForegroundColor Red

    $DriverScore -= 20
    $DriverIssues += "No GPU drivers found"
}

# ----------------------------------------------------------------------
# 5b. AUDIO DRIVERS
# ----------------------------------------------------------------------
Write-Host "`n[5b] AUDIO DRIVERS" -ForegroundColor Cyan

$AudioDrivers = $AllDrivers | Where-Object {
    $_.DeviceName -match "Audio|Sound|Realtek|HD Audio" -or
    $_.DriverProviderName -match "Realtek|Dolby|Nahimic"
}

if ($AudioDrivers.Count -gt 0) {
    $AudioDrivers |
        Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate |
        Format-Table -AutoSize

    foreach ($AudioDriver in $AudioDrivers) {
        if ($AudioDriver.DriverDate -lt (Get-Date).AddYears(-5)) {
            Write-Host "  WARNING: Very old audio driver ($($AudioDriver.DeviceName))" `
                -ForegroundColor Yellow

            $DriverWarnings += "Outdated audio driver: $($AudioDriver.DeviceName)"
            $DriverScore -= 5
        }
    }
} else {
    Write-Host "No audio controllers found. This is uncommon." `
        -ForegroundColor Yellow
}

# ----------------------------------------------------------------------
# 5c. NETWORK DRIVERS
# ----------------------------------------------------------------------
Write-Host "`n[5c] NETWORK DRIVERS" -ForegroundColor Cyan

$NetDrivers = $AllDrivers | Where-Object {
    $_.DeviceName -match "WiFi|Wireless|Ethernet|LAN|802\.11|Network"
}

if ($NetDrivers.Count -gt 0) {
    $NetDrivers |
        Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate |
        Format-Table -AutoSize

    foreach ($NetworkDriver in $NetDrivers) {
        if ($NetworkDriver.DriverDate -lt (Get-Date).AddYears(-4)) {
            Write-Host "  WARNING: Old network driver ($($NetworkDriver.DeviceName))" `
                -ForegroundColor Yellow

            $DriverWarnings += "Outdated network driver: $($NetworkDriver.DeviceName)"
            $DriverScore -= 5
        }

        if ($NetworkDriver.DeviceName -match "Realtek" -and
            $NetworkDriver.DriverProviderName -notmatch "Realtek") {

            Write-Host "  WARNING: Realtek NIC using a non-Realtek driver" `
                -ForegroundColor Yellow

            $DriverWarnings += "Potential incorrect NIC driver for Realtek device"
            $DriverScore -= 5
        }
    }
} else {
    Write-Host "No network adapters found." -ForegroundColor Red

    $DriverIssues += "Network drivers missing"
    $DriverScore -= 20
}

# ======================================================================
# 6. MULTIPLE DRIVER VERSIONS / CONFLICT CHECK
# ======================================================================
Write-Host "`n[6] MULTIPLE DRIVER VERSIONS / CONFLICT CHECK" `
    -ForegroundColor Yellow

$DuplicateDrivers = $AllDrivers |
    Group-Object DeviceName |
    Where-Object { $_.Count -gt 1 } |
    Select-Object Name, Count

if ($DuplicateDrivers.Count -gt 0) {
    Write-Host "Drivers with multiple entries detected:" `
        -ForegroundColor Yellow

    $DuplicateDrivers | Format-Table -AutoSize

    $DriverWarnings += "Multiple driver entries detected (may require review)"
    $DriverScore -= 10
} else {
    Write-Host "No duplicate driver entries detected." `
        -ForegroundColor Green
}

# ======================================================================
# 7. DRIVER FILE HEALTH CHECK
# ======================================================================
Write-Host "`n[7] DRIVER FILE HEALTH CHECK" -ForegroundColor Yellow

$MissingFiles = $AllDrivers | Where-Object {
    $_.Path -and -not (Test-Path $_.Path)
}

if ($MissingFiles.Count -gt 0) {
    Write-Host "Referenced driver files not found: $($MissingFiles.Count)" `
        -ForegroundColor Red

    $MissingFiles |
        Select-Object DeviceName, DriverProviderName, Path |
        Format-Table -AutoSize

    $DriverIssues += "Missing referenced driver files"
    $DriverScore -= 25
} else {
    Write-Host "All referenced driver files exist." -ForegroundColor Green
}

# ======================================================================
# 8. BOOT-CRITICAL DRIVER INFORMATION
# ======================================================================
Write-Host "`n[8] BOOT-CRITICAL DRIVER INFORMATION (IF ACCESSIBLE)" `
    -ForegroundColor Yellow

try {
    $BootDrivers = Get-CimInstance Win32_PnPSignedDriver | Where-Object {
        $_.IsBootCritical -eq $true
    }

    if ($BootDrivers.Count -gt 0) {
        $BootDrivers |
            Select-Object DeviceName, DriverProviderName, DriverVersion, IsBootCritical |
            Format-Table -AutoSize
    } else {
        Write-Host "No boot-critical driver classification found." `
            -ForegroundColor Gray
    }
} catch {
    Write-Host "Boot-critical driver data unavailable." -ForegroundColor Gray
}

# ======================================================================
# 9. FINAL DRIVER HEALTH SUMMARY
# ======================================================================
Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
Write-Host " FINAL DRIVER HEALTH SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$DriverScore = [math]::Max(0, $DriverScore)

Write-Host "`nDRIVER HEALTH SCORE: $DriverScore/100" `
    -ForegroundColor $(
        if ($DriverScore -ge 80) {
            "Green"
        } elseif ($DriverScore -ge 60) {
            "Yellow"
        } else {
            "Red"
        }
    )

if ($DriverIssues.Count -gt 0) {
    Write-Host "`nCRITICAL DRIVER ISSUES:" -ForegroundColor Red

    $DriverIssues |
        ForEach-Object {
            Write-Host "  • $_" -ForegroundColor Red
        }
}

if ($DriverWarnings.Count -gt 0) {
    Write-Host "`nDRIVER WARNINGS:" -ForegroundColor Yellow

    $DriverWarnings |
        ForEach-Object {
            Write-Host "  • $_" -ForegroundColor Yellow
        }
}

if (($DriverIssues.Count + $DriverWarnings.Count) -eq 0) {
    Write-Host "`nAll detected drivers passed the current audit checks." `
        -ForegroundColor Green
}

# Recommendations.
Write-Host "`nRECOMMENDATIONS:" -ForegroundColor Cyan

if ($DriverScore -ge 80) {
    Write-Host "  • Driver health is good. No urgent action indicated by this audit." `
        -ForegroundColor White
} else {
    Write-Host "  • Review outdated GPU, audio, and network drivers using vendor tools." `
        -ForegroundColor White
    Write-Host "  • Review duplicate driver entries where appropriate." `
        -ForegroundColor White
    Write-Host "  • Investigate devices with error codes in Device Manager." `
        -ForegroundColor White
    Write-Host "  • Avoid unsigned drivers unless their source and purpose are trusted." `
        -ForegroundColor White
}

Write-Host "`n=== DRIVER DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan

# ======================================================================
# 10. JSON EXPORT FOR PYTHON / LLM INTEGRATION
# ======================================================================

# Extract summary counts for the JSON payload to avoid unnecessarily
# large diagnostic output.
$UnsignedCountValue = if ($null -ne $UnsignedCount) {
    $UnsignedCount
} else {
    0
}

$OldDriversCountValue = if ($null -ne $OldDrivers) {
    $OldDrivers.Count
} else {
    0
}

$ProblemDevicesCountValue = if ($null -ne $ProblemDevices) {
    $ProblemDevices.Count
} else {
    0
}

$MissingFilesCountValue = if ($null -ne $MissingFiles) {
    $MissingFiles.Count
} else {
    0
}

$DuplicateCountValue = if ($null -ne $DuplicateDrivers) {
    $DuplicateDrivers.Count
} else {
    0
}

$DiagnosticResult = [ordered]@{
    "TotalDrivers"          = if ($null -ne $Total) { $Total } else { 0 }
    "DriverScore"           = $DriverScore
    "UnsignedDriversCount"  = $UnsignedCountValue
    "OldDriversCount"       = $OldDriversCountValue
    "ProblemDevicesCount"   = $ProblemDevicesCountValue
    "MissingFilesCount"     = $MissingFilesCountValue
    "DuplicateDriversCount" = $DuplicateCountValue
    "Issues"                = $DriverIssues
    "Warnings"              = $DriverWarnings
}

# Convert the diagnostic result to a compact JSON string.
$JsonOutput = $DiagnosticResult |
    ConvertTo-Json -Depth 3 -Compress

Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"
