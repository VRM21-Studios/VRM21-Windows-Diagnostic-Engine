# =====================================================================
# CPU DETAILED DIAGNOSTIC TOOL
# Mode    : Read-Only Audit
# Purpose : Assess CPU performance, health, and provide recommendations
# =====================================================================

Write-Host "=== CPU DETAILED DIAGNOSTIC ===" -ForegroundColor Cyan

# 1. Basic CPU Info
Write-Host "`n[1] CPU INFORMATION" -ForegroundColor Yellow
$CPU = Get-CimInstance Win32_Processor
Write-Host "Processor: $($CPU.Name)"
Write-Host "Cores/Threads: $($CPU.NumberOfCores)/$($CPU.NumberOfLogicalProcessors)"
Write-Host "Max Speed: $($CPU.MaxClockSpeed) MHz"
Write-Host "Current Speed: $([math]::Round($CPU.CurrentClockSpeed/1000, 2)) GHz"
Write-Host "L2 Cache: $($CPU.L2CacheSize) KB"
Write-Host "L3 Cache: $($CPU.L3CacheSize) KB"

# 2. Real-time CPU Usage (10 samples)
Write-Host "`n[2] REAL-TIME CPU USAGE (10 samples)" -ForegroundColor Yellow
1..10 | ForEach-Object {
    $Usage = (Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
    Write-Host "Sample $_ : $([math]::Round($Usage, 1))%" -ForegroundColor $(if($Usage -gt 80){"Red"}elseif($Usage -gt 50){"Yellow"}else{"Green"})
    Start-Sleep -Seconds 1
}

# 3. Per-Core Usage
Write-Host "`n[3] PER-CORE USAGE" -ForegroundColor Yellow
$CoreUsage = Get-Counter "\Processor(*)\% Processor Time" -SampleInterval 2 | 
    Where-Object {$_.CounterSamples.InstanceName -notlike "*_total*"} |
    Select-Object -ExpandProperty CounterSamples |
    Select-Object InstanceName, @{Name="Usage"; Expression={[math]::Round($_.CookedValue, 1)}}

$CoreUsage | Format-Table InstanceName, Usage -AutoSize

# 4. Top CPU Processes
Write-Host "`n[4] TOP CPU PROCESSES" -ForegroundColor Yellow
Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 |
    Format-Table ProcessName, Id, CPU, 
        @{Name="WorkingSet(MB)"; Expression={[math]::Round($_.WorkingSet/1MB, 2)}},
        @{Name="Threads"; Expression={$_.Threads.Count}} -AutoSize

# 5. CPU Temperature (if available)
Write-Host "`n[5] CPU TEMPERATURE & HEALTH" -ForegroundColor Yellow
try {
    $Temp = Get-CimInstance -Namespace root\WMI -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
    if ($Temp) {
        $CurrentTemp = ($Temp.CurrentTemperature / 10) - 273.15  # Convert to Celsius
        Write-Host "Current Temperature: $([math]::Round($CurrentTemp, 1))°C" -ForegroundColor $(if($CurrentTemp -gt 80){"Red"}elseif($CurrentTemp -gt 70){"Yellow"}else{"Green"})
    }
} catch {
    Write-Host "Temperature data not available" -ForegroundColor Gray
}

# 6. CPU Performance Recommendations
Write-Host "`n[6] PERFORMANCE RECOMMENDATIONS" -ForegroundColor Yellow
$AvgUsage = ($CoreUsage | Measure-Object -Property Usage -Average).Average
if ($AvgUsage -gt 80) {
    Write-Host " High CPU usage detected" -ForegroundColor Red
    Write-Host "   - Check for background processes" -ForegroundColor White
    Write-Host "   - Consider closing heavy applications" -ForegroundColor White
} elseif ($AvgUsage -gt 50) {
    Write-Host "  Moderate CPU usage" -ForegroundColor Yellow
} else {
    Write-Host " CPU usage optimal" -ForegroundColor Green
}

Write-Host "`n=== CPU DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan

# =====================================================================
# 7. JSON EXPORT FOR PYTHON / LLM INTEGRATION
# =====================================================================
# Ambil 5 proses teratas yang paling memakan CPU untuk dianalisis LLM
$Top5Processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | Select-Object ProcessName, Id, CPU

$DiagnosticResult = [ordered]@{
    "ProcessorName" = $CPU.Name
    "Cores"         = $CPU.NumberOfCores
    "Threads"       = $CPU.NumberOfLogicalProcessors
    "MaxSpeedMHz"   = $CPU.MaxClockSpeed
    "AvgUsagePct"   = if ($null -ne $AvgUsage) { [math]::Round($AvgUsage, 2) } else { 0 }
    "TemperatureC"  = if ($null -ne $CurrentTemp) { [math]::Round($CurrentTemp, 1) } else { $null }
    "TopProcesses"  = $Top5Processes
    "Status"        = if ($AvgUsage -gt 80) { "High" } elseif ($AvgUsage -gt 50) { "Moderate" } else { "Optimal" }
}

# Convert to JSON and output it as a pure string
$JsonOutput = $DiagnosticResult | ConvertTo-Json -Depth 3 -Compress
Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"
