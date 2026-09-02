# =====================================================================
# STORAGE DETAILED DIAGNOSTIC TOOL
# Mode    : Read-Only Audit
# Purpose : Assess storage health, performance, and optimization recommendations
# =====================================================================

Write-Host "=== STORAGE DETAILED DIAGNOSTIC ===" -ForegroundColor Cyan

# 1. Physical Disks Information
Write-Host "`n[1] PHYSICAL DISKS INFORMATION" -ForegroundColor Yellow

$Disks = Get-CimInstance Win32_DiskDrive

foreach ($Disk in $Disks) {
    Write-Host "`nDisk: $($Disk.Model)" -ForegroundColor White
    Write-Host "  Size: $([math]::Round($Disk.Size / 1GB, 2)) GB"
    Write-Host "  Interface: $($Disk.InterfaceType)"
    Write-Host "  Media Type: $($Disk.MediaType)"
    Write-Host "  Partitions: $($Disk.Partitions)"

    # Estimate whether the disk is an SSD based on model and media type.
    if (
        $Disk.Model -match "SSD|Solid State" -or
        $Disk.MediaType -match "SSD"
    ) {
        Write-Host "  Type: SSD" -ForegroundColor Green
    }
    else {
        Write-Host "  Type: HDD" -ForegroundColor Yellow
    }
}


# 2. Logical Drives Usage
Write-Host "`n[2] LOGICAL DRIVES USAGE" -ForegroundColor Yellow

$LogicalDrives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
$DrivesList = @()

foreach ($DriveObj in $LogicalDrives) {
    $Drive = $DriveObj.DeviceID
    $Size = [math]::Round($DriveObj.Size / 1GB, 2)
    $Free = [math]::Round($DriveObj.FreeSpace / 1GB, 2)
    $Used = $Size - $Free

    $Percent = if ($Size -gt 0) {
        [math]::Round(($Used / $Size) * 100, 2)
    }
    else {
        0
    }

    $Color = if ($Percent -lt 70) {
        "Green"
    }
    elseif ($Percent -lt 85) {
        "Yellow"
    }
    else {
        "Red"
    }

    Write-Host "Drive $Drive :" -ForegroundColor White
    Write-Host "  Size    : $Size GB"
    Write-Host "  Used    : $Used GB ($Percent%)" -ForegroundColor $Color
    Write-Host "  Free    : $Free GB"
    Write-Host "  FS Type : $($DriveObj.FileSystem)"

    $DrivesList += [ordered]@{
        "DriveLetter" = $Drive
        "SizeGB"      = $Size
        "UsedGB"      = $Used
        "FreeGB"      = $Free
        "UsedPercent" = $Percent
    }
}


# 3. Disk Performance Counters
Write-Host "`n[3] DISK PERFORMANCE COUNTERS" -ForegroundColor Yellow

try {
    $DiskRead = (
        Get-Counter "\PhysicalDisk(*)\Disk Read Bytes/sec" `
            -SampleInterval 2 `
            -MaxSamples 1
    ).CounterSamples |
        Where-Object { $_.InstanceName -eq "_Total" }

    $DiskWrite = (
        Get-Counter "\PhysicalDisk(*)\Disk Write Bytes/sec" `
            -SampleInterval 2 `
            -MaxSamples 1
    ).CounterSamples |
        Where-Object { $_.InstanceName -eq "_Total" }

    if ($DiskRead -and $DiskWrite) {
        $ReadMB = [math]::Round($DiskRead.CookedValue / 1MB, 2)
        $WriteMB = [math]::Round($DiskWrite.CookedValue / 1MB, 2)

        $ReadColor = if ($ReadMB -gt 100) {
            "Green"
        }
        elseif ($ReadMB -gt 50) {
            "Yellow"
        }
        else {
            "White"
        }

        $WriteColor = if ($WriteMB -gt 100) {
            "Green"
        }
        elseif ($WriteMB -gt 50) {
            "Yellow"
        }
        else {
            "White"
        }

        Write-Host "Current Read Speed: $ReadMB MB/s" -ForegroundColor $ReadColor
        Write-Host "Current Write Speed: $WriteMB MB/s" -ForegroundColor $WriteColor
    }
}
catch {
    Write-Host "Disk performance counters unavailable." -ForegroundColor Gray
}


# 4. Disk Health
Write-Host "`n[4] DISK HEALTH (SMART DATA)" -ForegroundColor Yellow

try {
    $SmartData = Get-CimInstance `
        -Namespace root\Microsoft\Windows\Storage `
        -ClassName MSFT_PhysicalDisk `
        -ErrorAction Stop

    foreach ($Disk in $SmartData) {
        Write-Host "`nDisk: $($Disk.FriendlyName)" -ForegroundColor White

        $HealthColor = switch ($Disk.HealthStatus) {
            "Healthy" {
                "Green"
            }
            "Warning" {
                "Yellow"
            }
            "Unhealthy" {
                "Red"
            }
            default {
                "White"
            }
        }

        Write-Host "  Health Status: $($Disk.HealthStatus)" `
            -ForegroundColor $HealthColor

        Write-Host "  Operational Status: $($Disk.OperationalStatus)"

        if ($Disk.SpareBlocks -or $Disk.Temperature) {
            if ($Disk.SpareBlocks) {
                Write-Host "  Spare Blocks: $($Disk.SpareBlocks)"
            }

            if ($Disk.Temperature) {
                Write-Host "  Temperature: $($Disk.Temperature)°C"
            }
        }
    }
}
catch {
    Write-Host "SMART data not available." -ForegroundColor Gray
}


# 5. Large File Analysis
Write-Host "`n[5] LARGE FILES ANALYSIS (TOP 20)" -ForegroundColor Yellow

try {
    $LargeFiles = Get-ChildItem C:\ `
        -Recurse `
        -File `
        -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First 20 |
        Select-Object Name,
            @{Name = "Size(MB)"; Expression = {
                [math]::Round($_.Length / 1MB, 2)
            }},
            Directory,
            LastWriteTime

    $LargeFiles | Format-Table -AutoSize
}
catch {
    Write-Host "Large file scan skipped due to permission issues." `
        -ForegroundColor Yellow
}


# 6. Temporary Files Analysis
Write-Host "`n[6] TEMPORARY FILES ANALYSIS" -ForegroundColor Yellow

$TempPaths = @(
    "$env:TEMP",
    "C:\Windows\Temp",
    "$env:LOCALAPPDATA\Temp"
)

$TotalTempSize = 0

foreach ($Path in $TempPaths) {
    if (Test-Path $Path) {
        $Size = (
            Get-ChildItem $Path `
                -Recurse `
                -File `
                -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum
        ).Sum / 1MB

        $SizeMB = [math]::Round($Size, 2)
        $TotalTempSize += $SizeMB

        $TempColor = if ($SizeMB -gt 500) {
            "Red"
        }
        elseif ($SizeMB -gt 100) {
            "Yellow"
        }
        else {
            "Green"
        }

        Write-Host "$Path : $SizeMB MB" -ForegroundColor $TempColor
    }
}

Write-Host "Total Temporary Files: $TotalTempSize MB" -ForegroundColor White


# 7. Storage Recommendations
Write-Host "`n[7] STORAGE RECOMMENDATIONS" -ForegroundColor Yellow

# Identify logical drives with more than 85% of their capacity in use.
$LowSpaceDrives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
    Where-Object {
        ($_.Size - $_.FreeSpace) / $_.Size -gt 0.85
    }

if ($LowSpaceDrives) {
    Write-Host "CRITICAL: Low disk space on drives:" -ForegroundColor Red

    foreach ($Drive in $LowSpaceDrives) {
        $Percent = [math]::Round(
            (($Drive.Size - $Drive.FreeSpace) / $Drive.Size) * 100,
            2
        )

        Write-Host "  - $($Drive.DeviceID) ($Percent% used)" `
            -ForegroundColor White
    }

    Write-Host "  Action: Clean up temporary files or move data." `
        -ForegroundColor White
}

if ($TotalTempSize -gt 1000) {
    Write-Host "WARNING: Large temporary file usage detected ($TotalTempSize MB)." `
        -ForegroundColor Yellow

    Write-Host "  Action: Run Disk Cleanup or remove unnecessary temporary files." `
        -ForegroundColor White
}


# SSD Optimization Check
$SSDDrives = $Disks |
    Where-Object {
        $_.Model -match "SSD|Solid State" -or
        $_.MediaType -match "SSD"
    }

if ($SSDDrives) {
    Write-Host "`nSSD OPTIMIZATION TIPS:" -ForegroundColor Cyan
    Write-Host "  - Ensure TRIM is enabled." -ForegroundColor White
    Write-Host "  - Avoid unnecessary manual defragmentation of SSDs." `
        -ForegroundColor White
    Write-Host "  - Keep at least 10-15% free space." -ForegroundColor White
}


Write-Host "`n=== STORAGE DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan


# 8. JSON EXPORT FOR PYTHON / LLM INTEGRATION
$DiskHealthList = @()

if ($null -ne $SmartData) {
    foreach ($d in $SmartData) {
        $DiskHealthList += [ordered]@{
            "Name"   = $d.FriendlyName
            "Health" = $d.HealthStatus
        }
    }
}

$DiagnosticResult = [ordered]@{
    "LogicalDrives"      = $DrivesList
    "ReadSpeedMBps"      = if ($null -ne $ReadMB) { $ReadMB } else { 0 }
    "WriteSpeedMBps"     = if ($null -ne $WriteMB) { $WriteMB } else { 0 }
    "DiskHealthStatus"   = $DiskHealthList
    "TotalTempFilesMB"   = if ($null -ne $TotalTempSize) { $TotalTempSize } else { 0 }
    "HasSSDOptimization" = if ($null -ne $SSDDrives) { $true } else { $false }
    "LowSpaceAlerts"     = if ($null -ne $LowSpaceDrives) {
        @($LowSpaceDrives).Count
    }
    else {
        0
    }
}

# Convert the diagnostic result to a compact JSON string.
$JsonOutput = $DiagnosticResult |
    ConvertTo-Json -Depth 3 -Compress

Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"
