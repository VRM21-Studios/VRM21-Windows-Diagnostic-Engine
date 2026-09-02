# =====================================================================
# LATENCY + THERMAL DETAILED DIAGNOSTIC TOOL
# =====================================================================

Write-Host "=== LATENCY & THERMAL DETAILED DIAGNOSTIC ===" -ForegroundColor Cyan

$LatencyScore = 100
$ThermalScore = 100
$LatencyIssues = @()
$LatencyWarnings = @()
$ThermalIssues = @()
$ThermalWarnings = @()

# =====================================================================
# 1. CPU / SYSTEM LATENCY OVERVIEW
# =====================================================================
Write-Host "`n[1] SYSTEM LATENCY OVERVIEW" -ForegroundColor Yellow

try {
    $CpuIntr = (Get-Counter "\Processor(_Total)\% Interrupt Time" -SampleInterval 1 -MaxSamples 3 |
        Select-Object -ExpandProperty CounterSamples | Select-Object -Last 1).CookedValue

    $CpuDpc = (Get-Counter "\Processor(_Total)\% DPC Time" -SampleInterval 1 -MaxSamples 3 |
        Select-Object -ExpandProperty CounterSamples | Select-Object -Last 1).CookedValue

    $CtxSwitch = (Get-Counter "\System\Context Switches/sec" -SampleInterval 1 -MaxSamples 3 |
        Select-Object -ExpandProperty CounterSamples | Select-Object -Last 1).CookedValue

    Write-Host "Current Interrupt Time : $([math]::Round($CpuIntr,2)) %" `
        -ForegroundColor $(if($CpuIntr -lt 1){"Green"}elseif($CpuIntr -lt 5){"Yellow"}else{"Red"})
    Write-Host "Current DPC Time       : $([math]::Round($CpuDpc,2)) %" `
        -ForegroundColor $(if($CpuDpc -lt 1){"Green"}elseif($CpuDpc -lt 5){"Yellow"}else{"Red"})
    Write-Host "Context Switches/sec   : $([math]::Round($CtxSwitch,0))"

    if ($CpuIntr -ge 5 -or $CpuDpc -ge 5) {
        $LatencyScore -= 25
        $LatencyIssues += "High DPC/Interrupt percentage"
    } elseif ($CpuIntr -ge 1 -or $CpuDpc -ge 1) {
        $LatencyScore -= 10
        $LatencyWarnings += "Moderate DPC/Interrupt activity (watch under gaming load)"
    }

    if ($CtxSwitch -gt 50000) {
        $LatencyWarnings += "High context switching rate; may indicate driver or heavy multitasking"
        $LatencyScore -= 10
    }

} catch {
    Write-Host "System latency counters unavailable: $($_.Exception.Message)" -ForegroundColor Red
    $LatencyScore -= 20
    $LatencyWarnings += "Cannot read core latency counters"
}

# =====================================================================
# 2. DPC / ISR PER-DRIVER (BEST EFFORT)
# =====================================================================
Write-Host "`n[2] DPC / ISR PER-DRIVER (BEST-EFFORT)" -ForegroundColor Yellow

$DriverGroups = $null
try {
    # NOTE: Counter object ini tidak ada di semua sistem; makanya dibungkus try/catch
    $drvCounters = Get-Counter '\Interrupts(*)\DPCs Queued/sec','\Interrupts(*)\ISRs/sec' -ErrorAction Stop

    $DriverGroups = @{}
    foreach ($sample in $drvCounters.CounterSamples) {
        $inst = $sample.InstanceName
        if ($inst -eq "_Total") { continue }
        if (-not $DriverGroups.ContainsKey($inst)) {
            $DriverGroups[$inst] = [ordered]@{DPC=0;ISR=0}
        }

        if ($sample.Path -like '*DPCs Queued*') {
            $DriverGroups[$inst].DPC = $sample.CookedValue
        } else {
            $DriverGroups[$inst].ISR = $sample.CookedValue
        }
    }

    if ($DriverGroups.Count -gt 0) {
        Write-Host "Top DPC/ISR sources:" -ForegroundColor White
        $DriverGroups.GetEnumerator() |
            Sort-Object { $_.Value.DPC + $_.Value.ISR } -Descending |
            Select-Object -First 10 `
                @{N="Driver";E={$_.Key}},
                @{N="DPC/sec";E={[math]::Round($_.Value.DPC,2)}},
                @{N="ISR/sec";E={[math]::Round($_.Value.ISR,2)}} |
            Format-Table -AutoSize
    } else {
        Write-Host "No per-driver DPC data found." -ForegroundColor Gray
    }
} catch {
    Write-Host "Per-driver DPC/ISR counters not available on this system." -ForegroundColor Gray
}

# =====================================================================
# 3. COMMON HIGH-LATENCY DRIVER NAME SCAN
# =====================================================================
Write-Host "`n[3] COMMON HIGH-LATENCY DRIVER PATTERN SCAN" -ForegroundColor Yellow

$CulpritPatterns = @(
    "ndis",     # Network stack
    "rtwlane",  # Realtek WiFi
    "rtw",      # Realtek WiFi variants
    "acpi",     # ACPI / BIOS
    "hda",      # Audio
    "rtk",      # Realtek audio
    "usb",      # USB host controllers
    "asmt",     # ASMedia USB/SATA
    "nvlddmkm", # NVIDIA GPU driver
    "amdpp",    # AMD power management
    "amdgpio"   # AMD GPIO
)

$FoundCulprits = @()

if ($DriverGroups -and $DriverGroups.Count -gt 0) {
    foreach ($pattern in $CulpritPatterns) {
        $hits = $DriverGroups.Keys | Where-Object { $_ -match $pattern }
        if ($hits) { $FoundCulprits += $hits }
    }
}

if ($FoundCulprits.Count -gt 0) {
    Write-Host "Potential high-latency driver instances detected:" -ForegroundColor Yellow
    $FoundCulprits | Sort-Object -Unique | Format-Table
    $LatencyWarnings += "Some known high-latency driver families are active; monitor under load"
} else {
    Write-Host "No common high-latency driver patterns detected (from available counters)." -ForegroundColor Green
}

# =====================================================================
# 4. NETWORK & DISK LATENCY SNAPSHOT (OPTIONAL BUT USEFUL)
# =====================================================================
Write-Host "`n[4] NETWORK & DISK LATENCY SNAPSHOT" -ForegroundColor Yellow

# ---- Disk Avg. Latency ----
try {
    $DiskLatency = Get-Counter '\PhysicalDisk(_Total)\Avg. Disk sec/Transfer' -SampleInterval 1 -MaxSamples 3 |
        Select-Object -ExpandProperty CounterSamples | Select-Object -Last 1

    $AvgDiskSec = $DiskLatency.CookedValue
    $AvgDiskMs = [math]::Round($AvgDiskSec * 1000, 2)

    Write-Host "Avg Disk Latency: $AvgDiskMs ms/transfer" -ForegroundColor `
        $(if($AvgDiskMs -lt 15){"Green"}elseif($AvgDiskMs -lt 30){"Yellow"}else{"Red"})

    if ($AvgDiskMs -gt 30) {
        $LatencyWarnings += "Disk latency higher than normal; check storage load or health"
        $LatencyScore -= 10
    }
} catch {
    Write-Host "Disk latency counters not available." -ForegroundColor Gray
}

# ---- Simple Network Latency Probe (best effort) ----
try {
    Write-Host "`nNetwork latency test (ICMP ping to 1.1.1.1)..." -ForegroundColor White
    $Ping = Test-NetConnection -ComputerName 1.1.1.1 -InformationLevel Quiet -ErrorAction SilentlyContinue
    if ($Ping) {
        $PingDetail = Test-NetConnection -ComputerName 1.1.1.1 -InformationLevel Detailed
        $LatencyMs = $PingDetail.PingReplyDetails.RoundtripTime
        Write-Host "Ping Latency: $LatencyMs ms" -ForegroundColor `
            $(if($LatencyMs -lt 40){"Green"}elseif($LatencyMs -lt 80){"Yellow"}else{"Red"})
    } else {
        Write-Host "Network latency test failed (no connectivity / blocked ICMP)." -ForegroundColor Gray
    }
} catch {
    Write-Host "Network latency test unavailable." -ForegroundColor Gray
}

# =====================================================================
# 5. CPU / SYSTEM THERMAL STATUS
# =====================================================================
Write-Host "`n[5] CPU & SYSTEM THERMAL STATUS" -ForegroundColor Yellow

$CpuTempC = $null
try {
    $TempZones = Get-CimInstance -Namespace root\WMI -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
    if ($TempZones) {
        # Ambil rata-rata semua zone, karena nama zone kadang aneh
        $TempsC = @()
        foreach ($tz in $TempZones) {
            if ($tz.CurrentTemperature) {
                $tC = ($tz.CurrentTemperature / 10) - 273.15
                if ($tC -gt 0 -and $tC -lt 120) { $TempsC += $tC }
            }
        }
        if ($TempsC.Count -gt 0) {
            $CpuTempC = [math]::Round(($TempsC | Measure-Object -Average).Average, 1)
            Write-Host "CPU / Package Temperature (approx): $CpuTempC °C" -ForegroundColor `
                $(if($CpuTempC -lt 75){"Green"}elseif($CpuTempC -lt 85){"Yellow"}else{"Red"})

            if ($CpuTempC -ge 90) {
                $ThermalIssues += "Severe CPU temperature (>= 90°C)"
                $ThermalScore -= 30
            } elseif ($CpuTempC -ge 85) {
                $ThermalWarnings += "High CPU temperature (85–90°C)"
                $ThermalScore -= 20
            } elseif ($CpuTempC -ge 75) {
                $ThermalWarnings += "Elevated CPU temperature (75–85°C)"
                $ThermalScore -= 10
            }
        } else {
            Write-Host "Thermal zone returned invalid temperature data." -ForegroundColor Gray
        }
    } else {
        Write-Host "No ACPI thermal zones found." -ForegroundColor Gray
    }
} catch {
    Write-Host "CPU thermal data not available (WMI ACPI)." -ForegroundColor Gray
}

# UPTIME, useful to interpret temp (misal baru boot vs sudah lama full load)
try {
    $LastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $Uptime = (Get-Date) - $LastBoot
    Write-Host "System Uptime: $($Uptime.Days) days, $($Uptime.Hours) hours, $($Uptime.Minutes) minutes"
} catch {}

# =====================================================================
# 6. GPU THERMAL STATUS (BEST EFFORT VIA WMI)
# =====================================================================
Write-Host "`n[6] GPU THERMAL STATUS (BEST-EFFORT)" -ForegroundColor Yellow

$GpuTempFound = $false

try {
    $TempNamespaces = @(
        "root\WMI",
        "root\CIMV2",
        "root\Microsoft\Windows\Storage"
    )

    foreach ($ns in $TempNamespaces) {
        try {
            $classes = Get-CimClass -Namespace $ns -ErrorAction SilentlyContinue | 
                Where-Object {$_.CimClassName -match "temperature|Thermal"}
            foreach ($c in $classes) {
                $inst = Get-CimInstance -Namespace $ns -ClassName $c.CimClassName -ErrorAction SilentlyContinue
                foreach ($t in $inst) {
                    $nameStr = ($t.Name, $t.InstanceName, $t.Description -join " ") -as [string]
                    if ($nameStr -match "GPU|Video|Graphics") {
                        $raw = ($t.CurrentTemperature, $t.Temperature, $t.Temperature_Celsius | Where-Object {$_}) | Select-Object -First 1
                        if ($raw) {
                            $guess = [double]$raw
                            if ($guess -gt 150) { $guess = ($guess / 10) - 273.15 }
                            $guess = [math]::Round($guess,1)

                            Write-Host "GPU Temperature (from $($c.CimClassName)) : $guess °C" -ForegroundColor `
                                $(if($guess -lt 80){"Green"}elseif($guess -lt 88){"Yellow"}else{"Red"})

                            if ($guess -ge 90) {
                                $ThermalIssues += "Severe GPU temperature (>= 90°C)"
                                $ThermalScore -= 25
                            } elseif ($guess -ge 85) {
                                $ThermalWarnings += "High GPU temperature (85–90°C)"
                                $ThermalScore -= 15
                            } elseif ($guess -ge 80) {
                                $ThermalWarnings += "Elevated GPU temperature (80–85°C)"
                                $ThermalScore -= 10
                            }

                            $GpuTempFound = $true
                            break
                        }
                    }
                }
                if ($GpuTempFound) { break }
            }
            if ($GpuTempFound) { break }
        } catch {}
    }

    if (-not $GpuTempFound) {
        Write-Host "GPU temperature not accessible via generic WMI." -ForegroundColor Gray
        Write-Host "  Use vendor tools (NVIDIA/AMD/Intel overlay, MSI Afterburner, dsb.) for precise GPU temps." -ForegroundColor White
    }
} catch {
    Write-Host "GPU thermal query failed." -ForegroundColor Gray
}

# =====================================================================
# 7. DISK THERMAL SNAPSHOT (IF AVAILABLE)
# =====================================================================
Write-Host "`n[7] DISK THERMAL SNAPSHOT" -ForegroundColor Yellow

try {
    $DiskSmart = Get-CimInstance -Namespace root\Microsoft\Windows\Storage -ClassName MSFT_PhysicalDisk -ErrorAction Stop
    foreach ($d in $DiskSmart) {
        Write-Host "Disk: $($d.FriendlyName)" -ForegroundColor White
        if ($d.Temperature) {
            $dt = [double]$d.Temperature
            Write-Host "  Temperature: $dt °C" -ForegroundColor `
                $(if($dt -lt 50){"Green"}elseif($dt -lt 60){"Yellow"}else{"Red"})
            if ($dt -ge 60) {
                $ThermalWarnings += "Disk $($d.FriendlyName) running hot (>= 60°C)"
                $ThermalScore -= 10
            }
        } else {
            Write-Host "  Temperature: N/A"
        }
        Write-Host "  Health     : $($d.HealthStatus)"
    }
} catch {
    Write-Host "Disk SMART / thermal data not available." -ForegroundColor Gray
}

# =====================================================================
# 8. REAL-TIME SNAPSHOT LOOP (SHORT, FOR VISUAL CHECK)
# =====================================================================
Write-Host "`n[8] SHORT REAL-TIME SNAPSHOT (CPU Load + Interrupts + Context Switches)" -ForegroundColor Yellow
Write-Host "   (5 samples, 1s interval)" -ForegroundColor Gray

for ($i=1; $i -le 5; $i++) {
    try {
        $cpuLoad = (Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
        $intrNow = (Get-Counter "\Processor(_Total)\% Interrupt Time" -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
        $ctxNow = (Get-Counter "\System\Context Switches/sec" -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue

        Write-Host ("Sample {0}: CPU {1,5:N1}% | Intr {2,4:N2}% | Ctx {3,8:N0}/s" -f `
            $i, $cpuLoad, $intrNow, $ctxNow) -ForegroundColor `
            $(if($cpuLoad -gt 90 -or $intrNow -gt 5){"Red"}elseif($cpuLoad -gt 70){"Yellow"}else{"Green"})
    } catch {
        Write-Host " Real-time counters not available in this environment." -ForegroundColor Gray
        break
    }
}

# =====================================================================
# 9. FINAL LATENCY & THERMAL ASSESSMENT
# =====================================================================
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host " FINAL LATENCY & THERMAL ASSESSMENT" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

$LatencyScore = [math]::Max(0, $LatencyScore)
$ThermalScore = [math]::Max(0, $ThermalScore)

$OverallScore = [math]::Round(($LatencyScore + $ThermalScore) / 2)

Write-Host "`nLatency Score : $LatencyScore/100" -ForegroundColor `
    $(if($LatencyScore -ge 80){"Green"}elseif($LatencyScore -ge 60){"Yellow"}else{"Red"})

Write-Host "Thermal Score : $ThermalScore/100" -ForegroundColor `
    $(if($ThermalScore -ge 80){"Green"}elseif($ThermalScore -ge 60){"Yellow"}else{"Red"})

Write-Host "`nOVERALL LATENCY/THERMAL HEALTH: $OverallScore/100" -ForegroundColor `
    $(if($OverallScore -ge 80){"Green"}elseif($OverallScore -ge 60){"Yellow"}else{"Red"})

if ($LatencyIssues.Count -gt 0) {
    Write-Host "`n CRITICAL LATENCY ISSUES:" -ForegroundColor Red
    $LatencyIssues | Sort-Object -Unique | ForEach-Object { Write-Host "   • $_" -ForegroundColor Red }
}

if ($LatencyWarnings.Count -gt 0) {
    Write-Host "`n LATENCY WARNINGS:" -ForegroundColor Yellow
    $LatencyWarnings | Sort-Object -Unique | ForEach-Object { Write-Host "   • $_" -ForegroundColor Yellow }
}

if ($ThermalIssues.Count -gt 0) {
    Write-Host "`n CRITICAL THERMAL ISSUES:" -ForegroundColor Red
    $ThermalIssues | Sort-Object -Unique | ForEach-Object { Write-Host "   • $_" -ForegroundColor Red }
}

if ($ThermalWarnings.Count -gt 0) {
    Write-Host "`n THERMAL WARNINGS:" -ForegroundColor Yellow
    $ThermalWarnings | Sort-Object -Unique | ForEach-Object { Write-Host "   • $_" -ForegroundColor Yellow }
}

Write-Host "`n RECOMMENDATIONS:" -ForegroundColor Cyan

if ($OverallScore -ge 80) {
    Write-Host "   • System latency and thermal conditions are excellent for normal use and gaming." -ForegroundColor White
    Write-Host "   • Only requires monitoring during sustained full load (heavy rendering / gaming)." -ForegroundColor White
} elseif ($OverallScore -ge 60) {
    Write-Host "   • Check drivers (network/audio/USB/GPU) if you experience stuttering during gaming." -ForegroundColor White
    Write-Host "   • Ensure adequate chassis/laptop airflow and avoid overly silent fan profiles." -ForegroundColor White
    Write-Host "   • Monitor CPU/GPU temperatures under heavy load using vendor-specific tools." -ForegroundColor White
} else {
    Write-Host "   • High latency or excessive temperatures detected — high risk of stuttering or thermal throttling." -ForegroundColor White
    Write-Host "   • Update/rollback suspicious drivers; disable unnecessary devices (legacy WiFi, virtual audio, etc.)." -ForegroundColor White
    Write-Host "   • Clean dust from vents, consider repasting CPU/GPU, and verify fan operation." -ForegroundColor White
}

# =====================================================================
# 10. JSON EXPORT FOR PYTHON / LLM INTEGRATION
# =====================================================================
$DiagnosticResult = [ordered]@{
    "LatencyScore"      = $LatencyScore
    "ThermalScore"      = $ThermalScore
    "OverallScore"      = $OverallScore
    "CpuInterruptPct"   = if ($null -ne $CpuIntr) { [math]::Round($CpuIntr, 2) } else { 0 }
    "CpuDpcPct"         = if ($null -ne $CpuDpc) { [math]::Round($CpuDpc, 2) } else { 0 }
    "ContextSwitches"   = if ($null -ne $CtxSwitch) { [math]::Round($CtxSwitch, 0) } else { 0 }
    "AvgDiskLatencyMs"  = if ($null -ne $AvgDiskMs) { $AvgDiskMs } else { 0 }
    "PingLatencyMs"     = if ($null -ne $LatencyMs) { $LatencyMs } else { 0 }
    "CpuTempC"          = if ($null -ne $CpuTempC) { $CpuTempC } else { $null }
    "GpuTempFound"      = $GpuTempFound
    "HighLatencyDrivers"= $FoundCulprits
    "LatencyIssues"     = $LatencyIssues
    "LatencyWarnings"   = $LatencyWarnings
    "ThermalIssues"     = $ThermalIssues
    "ThermalWarnings"   = $ThermalWarnings
}

# Convert to JSON and output it as a pure string
$JsonOutput = $DiagnosticResult | ConvertTo-Json -Depth 3 -Compress
Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"