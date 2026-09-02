# ======================================================================
# Battery Detailed Diagnostic
# Version : 1.0
# Mode    : Read-Only Audit
# Purpose : Assess battery health, wear level, cycle count, and provide
#           recommendations
# ======================================================================

Write-Host "===================================================="
Write-Host " BATTERY DETAILED DIAGNOSTIC"
Write-Host "====================================================`n"

$BatteryScore = 100
$BattIssues = @()
$BattWarnings = @()

# ----------------------------------------------------------------------
# 1. BASIC BATTERY INFORMATION
# ----------------------------------------------------------------------
Write-Host "`n[1] BASIC BATTERY INFORMATION" -ForegroundColor Yellow

try {
    $Batt = Get-CimInstance Win32_Battery -ErrorAction Stop

    if ($Batt) {
        Write-Host "Status                     : $($Batt.BatteryStatus)"
        Write-Host "Estimated Charge Remaining : $($Batt.EstimatedChargeRemaining)%"
        Write-Host "Estimated Run Time         : $($Batt.EstimatedRunTime) minutes"
        Write-Host "Chemistry                  : $($Batt.Chemistry)"
        Write-Host "Design Voltage             : $($Batt.DesignVoltage) mV"

        # Interpret the battery status code.
        switch ($Batt.BatteryStatus) {
            1 {
                Write-Host "State: Discharging" -ForegroundColor Yellow
            }
            2 {
                Write-Host "State: AC Connected" -ForegroundColor Green
            }
            3 {
                Write-Host "State: Fully Charged" -ForegroundColor Green
            }
            4 {
                Write-Host "State: Low Battery" -ForegroundColor Red
                $BatteryScore -= 10
            }
            5 {
                Write-Host "State: Critical Battery" -ForegroundColor Red
                $BatteryScore -= 20
            }
        }
    }
}
catch {
    Write-Host "No battery detected (likely desktop system)" -ForegroundColor Gray
    return
}

# ----------------------------------------------------------------------
# 2. DETAILED CAPACITY AND WEAR LEVEL
# ----------------------------------------------------------------------
Write-Host "`n[2] BATTERY CAPACITY & WEAR LEVEL" -ForegroundColor Yellow

$TempReport = "$env:TEMP\battery_report.html"

powercfg /batteryreport /output $TempReport | Out-Null

Start-Sleep -Milliseconds 400

$DesignCap = $null
$FullChargeCap = $null
$Wear = $null

if (Test-Path $TempReport) {
    $ReportContent = Get-Content $TempReport -Raw

    # Extract battery capacity values from the generated HTML report.
    if ($ReportContent -match "DESIGN CAPACITY</td><td.*?>([\d,]+) mWh") {
        $DesignCap = ($Matches[1] -replace ",", "") -as [int]
    }

    if ($ReportContent -match "FULL CHARGE CAPACITY</td><td.*?>([\d,]+) mWh") {
        $FullChargeCap = ($Matches[1] -replace ",", "") -as [int]
    }

    if ($DesignCap -and $FullChargeCap) {
        $Wear = [math]::Round(
            (1 - ($FullChargeCap / $DesignCap)) * 100,
            2
        )

        Write-Host "Design Capacity     : $DesignCap mWh"
        Write-Host "Full Charge Capacity: $FullChargeCap mWh"

        Write-Host "Battery Wear Level  : $Wear%" -ForegroundColor `
            $(if ($Wear -lt 10) {
                "Green"
            }
            elseif ($Wear -lt 20) {
                "Yellow"
            }
            else {
                "Red"
            })

        if ($Wear -gt 20) {
            $BatteryScore -= 20
            $BattWarnings += "Battery wear level high ($Wear%)"
        }
    }
    else {
        Write-Host "Unable to extract capacity information from battery report." `
            -ForegroundColor Gray
    }
}

# ----------------------------------------------------------------------
# 3. BATTERY CYCLE COUNT
# ----------------------------------------------------------------------
Write-Host "`n[3] BATTERY CYCLE COUNT" -ForegroundColor Yellow

$CycleCount = $null

try {
    $Cycle = Get-CimInstance `
        -Namespace root\wmi `
        -ClassName BatteryCycleCount `
        -ErrorAction Stop

    if ($Cycle) {
        $CycleCount = $Cycle.CycleCount

        Write-Host "Cycle Count: $CycleCount"

        if ($CycleCount -gt 500) {
            $BatteryScore -= 10
            $BattWarnings += "High cycle count ($CycleCount)"
        }
    }
}
catch {
    Write-Host "Cycle count not available on this system." -ForegroundColor Gray
}

# ----------------------------------------------------------------------
# 4. POWER STATE AND DISCHARGE RATE
# ----------------------------------------------------------------------
Write-Host "`n[4] POWER STATE & DISCHARGE RATE" -ForegroundColor Yellow

$PowerStatus = Get-CimInstance Win32_PowerMeter -ErrorAction SilentlyContinue

if ($PowerStatus -and $PowerStatus.Power) {
    $Watt = [math]::Round($PowerStatus.Power / 1000, 2)

    Write-Host "Current Power Draw: $Watt W"

    if ($Watt -gt 20 -and $Batt.BatteryStatus -eq 1) {
        Write-Host "High discharge rate detected!" -ForegroundColor Red

        $BattWarnings += "High power draw: ${Watt}W"
        $BatteryScore -= 10
    }
}
else {
    Write-Host "Power draw information unavailable" -ForegroundColor Gray
}

# ----------------------------------------------------------------------
# 5. BATTERY TEMPERATURE
# ----------------------------------------------------------------------
Write-Host "`n[5] BATTERY TEMPERATURE" -ForegroundColor Yellow

try {
    $Thermal = Get-CimInstance `
        -Namespace root\wmi `
        -ClassName MSAcpi_ThermalZoneTemperature `
        -ErrorAction Stop

    $Temps = @()

    foreach ($T in $Thermal) {
        $C = ($T.CurrentTemperature / 10) - 273.15

        if ($T.InstanceName -match "BAT" -or $T.InstanceName -match "Battery") {
            $Temps += $C

            Write-Host "Battery Temperature: $([math]::Round($C, 1))°C" `
                -ForegroundColor `
                $(if ($C -gt 50) {
                    "Red"
                }
                elseif ($C -gt 40) {
                    "Yellow"
                }
                else {
                    "Green"
                })

            if ($C -gt 50) {
                $BatteryScore -= 20
                $BattIssues += "Battery overheating (>50°C)"
            }
        }
    }

    if ($Temps.Count -eq 0) {
        Write-Host "Battery temperature not exposed by firmware." `
            -ForegroundColor Gray
    }
}
catch {
    Write-Host "Battery temperature unavailable." -ForegroundColor Gray
}

# ----------------------------------------------------------------------
# 6. BATTERY HEALTH SCORE AND FINAL RECOMMENDATIONS
# ----------------------------------------------------------------------
Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
Write-Host " BATTERY HEALTH SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

Write-Host "`nFinal Battery Score: $BatteryScore/100" -ForegroundColor `
    $(if ($BatteryScore -ge 80) {
        "Green"
    }
    elseif ($BatteryScore -ge 60) {
        "Yellow"
    }
    else {
        "Red"
    })

if ($BattIssues) {
    Write-Host "`n CRITICAL ISSUES:" -ForegroundColor Red
    $BattIssues | ForEach-Object {
        Write-Host "  • $_" -ForegroundColor Red
    }
}

if ($BattWarnings) {
    Write-Host "`n WARNINGS:" -ForegroundColor Yellow
    $BattWarnings | ForEach-Object {
        Write-Host "  • $_" -ForegroundColor Yellow
    }
}

Write-Host "`n RECOMMENDATIONS:" -ForegroundColor Cyan

if ($BatteryScore -ge 80) {
    Write-Host "  • Battery health is good — keep between 20–80% when possible."
    Write-Host "  • Avoid heavy discharge during gaming without charger."
}
elseif ($BatteryScore -ge 60) {
    Write-Host "  • Consider reducing heat exposure."
    Write-Host "  • Do occasional calibration (full discharge → full charge)."
}
else {
    Write-Host "  • Battery severely degraded — consider replacement."
    Write-Host "  • Avoid high temperatures and sustained high wattage discharging."
}

Write-Host "`n=== BATTERY DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan

# ----------------------------------------------------------------------
# 7. JSON EXPORT FOR PYTHON / LLM INTEGRATION
# ----------------------------------------------------------------------
$DiagnosticResult = [ordered]@{
    "BatteryScore"  = $BatteryScore
    "Status"        = $Batt.BatteryStatus
    "Chemistry"     = $Batt.Chemistry
    "WearLevelPct"  = $Wear
    "CycleCount"    = $CycleCount
    "DischargeRate" = $Watt
    "Issues"        = $BattIssues
    "Warnings"      = $BattWarnings
}

# Output JSON between stable markers so the Python engine can capture it.
$JsonOutput = $DiagnosticResult | ConvertTo-Json -Depth 3 -Compress

Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"
