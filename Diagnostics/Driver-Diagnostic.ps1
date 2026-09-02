# =====================================================================
# DRIVER DETAILED DIAGNOSTIC TOOL
# =====================================================================

Write-Host "=== DRIVER DETAILED DIAGNOSTIC ===" -ForegroundColor Cyan

$DriverScore = 100
$DriverIssues = @()
$DriverWarnings = @()

# =====================================================================
# 1. DRIVER INVENTORY SUMMARY
# =====================================================================
Write-Host "`n[1] DRIVER INVENTORY SUMMARY" -ForegroundColor Yellow

try {
    $AllDrivers = Get-CimInstance Win32_PnPSignedDriver
    $Total = $AllDrivers.Count
    Write-Host "Total Installed Drivers : $Total" -ForegroundColor Cyan

    $Unsigned = $AllDrivers | Where-Object { $_.IsSigned -eq $false }
    $UnsignedCount = $Unsigned.Count

    Write-Host "Unsigned Drivers        : $UnsignedCount" -ForegroundColor `
        $(if($UnsignedCount -eq 0){"Green"}elseif($UnsignedCount -lt 10){"Yellow"}else{"Red"})

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

# =====================================================================
# 2. UNSIGNED DRIVERS LIST (IMPORTANT)
# =====================================================================
Write-Host "`n[2] UNSIGNED DRIVERS" -ForegroundColor Yellow

if ($UnsignedCount -gt 0) {
    $Unsigned | Select-Object DeviceName, DriverVersion, DriverProviderName, Manufacturer, Path |
        Format-Table -AutoSize
} else {
    Write-Host "No unsigned drivers detected." -ForegroundColor Green
}

# =====================================================================
# 3. OUTDATED DRIVER ANALYSIS (BASED ON DATE)
# =====================================================================
Write-Host "`n[3] OUTDATED DRIVER ANALYSIS" -ForegroundColor Yellow

$OldDrivers = $AllDrivers | Where-Object { $_.DriverDate -lt (Get-Date).AddYears(-5) }

if ($OldDrivers.Count -gt 0) {
    Write-Host "Drivers older than 5 years: $($OldDrivers.Count)" -ForegroundColor Yellow
    $OldDrivers | Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate |
        Sort-Object DriverDate |
        Format-Table -AutoSize

    if ($OldDrivers.Count -gt 20) {
        $DriverScore -= 20
        $DriverIssues += "Large number of ancient drivers detected"
    } else {
        $DriverScore -= 10
        $DriverWarnings += "Some drivers are outdated"
    }
} else {
    Write-Host "No outdated drivers detected." -ForegroundColor Green
}

# =====================================================================
# 4. DEVICE MANAGER PROBLEM DEVICES
# =====================================================================
Write-Host "`n[4] DEVICE PROBLEM REPORT (DEVICE MANAGER STATUS)" -ForegroundColor Yellow

try {
    $ProblemDevices = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }

    if ($ProblemDevices.Count -gt 0) {
        Write-Host "Devices with Errors: $($ProblemDevices.Count)" -ForegroundColor Red
        $ProblemDevices | Select-Object Name, Manufacturer, ConfigManagerErrorCode |
            Format-Table -AutoSize

        $DriverScore -= 25
        $DriverIssues += "Devices with error codes detected"
    } else {
        Write-Host "No device problems detected." -ForegroundColor Green
    }
} catch {
    Write-Host "Unable to retrieve device problem list." -ForegroundColor Gray
}

# =====================================================================
# 5. DRIVER CATEGORY CHECK (GPU / AUDIO / NETWORK)
# =====================================================================
Write-Host "`n[5] CRITICAL DRIVER CATEGORY CHECK" -ForegroundColor Yellow

### GPU DRIVERS
Write-Host "`n[a] GPU DRIVERS:" -ForegroundColor Cyan
$GPUDrivers = $AllDrivers | Where-Object { $_.DeviceName -match "NVIDIA|AMD|Intel" -and $_.DriverProviderName -match "NVIDIA|AMD|Intel" }

if ($GPUDrivers.Count -gt 0) {
    $GPUDrivers | Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate |
        Format-Table -AutoSize

    foreach ($gpu in $GPUDrivers) {
        if ($gpu.DriverDate -lt (Get-Date).AddYears(-3)) {
            Write-Host "   WARNING: GPU driver outdated ($($gpu.DeviceName))" -ForegroundColor Yellow
            $DriverWarnings += "Outdated GPU driver: $($gpu.DeviceName)"
            $DriverScore -= 10
        }
    }
} else {
    Write-Host "No GPU drivers detected??? (Unusual)" -ForegroundColor Red
    $DriverScore -= 20
    $DriverIssues += "No GPU drivers found"
}

### AUDIO DRIVERS
Write-Host "`n[b] AUDIO DRIVERS:" -ForegroundColor Cyan
$AudioDrivers = $AllDrivers | Where-Object {
    $_.DeviceName -match "Audio|Sound|Realtek|HD Audio" -or
    $_.DriverProviderName -match "Realtek|Dolby|Nahimic"
}

if ($AudioDrivers.Count -gt 0) {
    $AudioDrivers | Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate |
        Format-Table -AutoSize

    foreach ($ad in $AudioDrivers) {
        if ($ad.DriverDate -lt (Get-Date).AddYears(-5)) {
            Write-Host "   WARNING: Very old audio driver ($($ad.DeviceName))" -ForegroundColor Yellow
            $DriverWarnings += "Outdated audio driver: $($ad.DeviceName)"
            $DriverScore -= 5
        }
    }
} else {
    Write-Host "No audio controllers found? (This is rare)" -ForegroundColor Yellow
}

### NETWORK DRIVERS
Write-Host "`n[c] NETWORK DRIVERS:" -ForegroundColor Cyan
$NetDrivers = $AllDrivers | Where-Object {
    $_.DeviceName -match "WiFi|Wireless|Ethernet|LAN|802\.11|Network"
}

if ($NetDrivers.Count -gt 0) {
    $NetDrivers | Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate |
        Format-Table -AutoSize

    foreach ($nd in $NetDrivers) {
        if ($nd.DriverDate -lt (Get-Date).AddYears(-4)) {
            Write-Host "   WARNING: Old network driver ($($nd.DeviceName))" -ForegroundColor Yellow
            $DriverWarnings += "Outdated network driver: $($nd.DeviceName)"
            $DriverScore -= 5
        }
        if ($nd.DeviceName -match "Realtek" -and $nd.DriverProviderName -notmatch "Realtek") {
            Write-Host "   WARNING: Realtek NIC using non-Realtek driver" -ForegroundColor Yellow
            $DriverWarnings += "Potential wrong NIC driver for Realtek"
            $DriverScore -= 5
        }
    }
} else {
    Write-Host "No network adapters found." -ForegroundColor Red
    $DriverIssues += "Network drivers missing"
    $DriverScore -= 20
}

# =====================================================================
# 6. DRIVER VERSION DUPLICATION / CONFLICT ANALYSIS
# =====================================================================
Write-Host "`n[6] MULTIPLE DRIVER VERSIONS / CONFLICT CHECK" -ForegroundColor Yellow

$DuplicateDrivers = $AllDrivers |
    Group-Object DeviceName |
    Where-Object { $_.Count -gt 1 } |
    Select-Object Name, Count

if ($DuplicateDrivers.Count -gt 0) {
    Write-Host "Drivers with multiple versions installed:" -ForegroundColor Yellow
    $DuplicateDrivers | Format-Table -AutoSize

    $DriverWarnings += "Multiple driver versions installed (may cause instability)"
    $DriverScore -= 10

} else {
    Write-Host "No duplicated drivers detected." -ForegroundColor Green
}

# =====================================================================
# 7. DRIVER FILE HEALTH CHECK (missing, corrupted)
# =====================================================================
Write-Host "`n[7] DRIVER FILE HEALTH CHECK" -ForegroundColor Yellow

$MissingFiles = $AllDrivers | Where-Object { $_.Path -and -not (Test-Path $_.Path) }

if ($MissingFiles.Count -gt 0) {
    Write-Host "Broken driver file entries detected: $($MissingFiles.Count)" -ForegroundColor Red
    $MissingFiles | Select-Object DeviceName, DriverProviderName, Path |
        Format-Table -AutoSize

    $DriverIssues += "Missing driver files (corrupted installation)"
    $DriverScore -= 25
} else {
    Write-Host "All referenced driver files exist." -ForegroundColor Green
}

# =====================================================================
# 8. DRIVER LOAD TIME (Boot-critical drivers)
# =====================================================================
Write-Host "`n[8] BOOT-CRITICAL DRIVER LOAD TIME (if accessible)" -ForegroundColor Yellow

try {
    $BootDrivers = Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.IsBootCritical -eq $true }

    if ($BootDrivers.Count -gt 0) {
        $BootDrivers | Select-Object DeviceName, DriverProviderName, DriverVersion, IsBootCritical |
            Format-Table -AutoSize
    } else {
        Write-Host "No boot-critical driver classification found." -ForegroundColor Gray
    }
} catch {
    Write-Host "Boot-critical driver data unavailable." -ForegroundColor Gray
}

# =====================================================================
# 9. FINAL DRIVER HEALTH SUMMARY
# =====================================================================
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host " FINAL DRIVER HEALTH SUMMARY" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

$DriverScore = [math]::Max(0, $DriverScore)

Write-Host "`nDRIVER HEALTH SCORE: $DriverScore/100" -ForegroundColor `
    $(if ($DriverScore -ge 80) { "Green" } elseif ($DriverScore -ge 60) { "Yellow" } else { "Red" })

if ($DriverIssues.Count -gt 0) {
    Write-Host "`n CRITICAL DRIVER ISSUES:" -ForegroundColor Red
    $DriverIssues | ForEach-Object { Write-Host "   • $_" -ForegroundColor Red }
}

if ($DriverWarnings.Count -gt 0) {
    Write-Host "`n DRIVER WARNINGS:" -ForegroundColor Yellow
    $DriverWarnings | ForEach-Object { Write-Host "   • $_" -ForegroundColor Yellow }
}

if (($DriverIssues.Count + $DriverWarnings.Count) -eq 0) {
    Write-Host "`n All drivers in good condition!" -ForegroundColor Green
}

# RECOMMENDATIONS
Write-Host "`nRECOMMENDATIONS:" -ForegroundColor Cyan

if ($DriverScore -ge 80) {
    Write-Host "   • Driver health excellent. No urgent action needed." -ForegroundColor White
} else {
    Write-Host "   • Update outdated GPU/Audio/Network drivers via vendor tools." -ForegroundColor White
    Write-Host "   • Remove duplicate driver versions if unnecessary." -ForegroundColor White
    Write-Host "   • Investigate devices with error codes in Device Manager." -ForegroundColor White
    Write-Host "   • Avoid unsigned drivers unless from trusted sources." -ForegroundColor White
}

Write-Host "`n=== DRIVER DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan

# =====================================================================
# 10. JSON EXPORT FOR PYTHON / LLM INTEGRATION
# =====================================================================
# Extract simple counts for JSON payload to avoid massive data strings
$UnsignedCountValue = if ($null -ne $UnsignedCount) { $UnsignedCount } else { 0 }
$OldDriversCountValue = if ($null -ne $OldDrivers) { $OldDrivers.Count } else { 0 }
$ProblemDevicesCountValue = if ($null -ne $ProblemDevices) { $ProblemDevices.Count } else { 0 }
$MissingFilesCountValue = if ($null -ne $MissingFiles) { $MissingFiles.Count } else { 0 }
$DuplicateCountValue = if ($null -ne $DuplicateDrivers) { $DuplicateDrivers.Count } else { 0 }

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

# Convert to JSON and output it as a pure string
$JsonOutput = $DiagnosticResult | ConvertTo-Json -Depth 3 -Compress
Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"