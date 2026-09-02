# =====================================================================
# RAM DETAILED DIAGNOSTIC TOOL
# =====================================================================

Write-Host "=== RAM DETAILED DIAGNOSTIC ===" -ForegroundColor Cyan

# 1. Physical Memory Information
Write-Host "`n[1] PHYSICAL MEMORY" -ForegroundColor Yellow
$RAM = Get-CimInstance Win32_PhysicalMemory
$TotalRAM = ($RAM | Measure-Object -Property Capacity -Sum).Sum / 1GB
Write-Host "Total Installed: $([math]::Round($TotalRAM, 2)) GB"
Write-Host "Modules: $($RAM.Count)"
$RAM | Format-Table Manufacturer, PartNumber, 
    @{Name="Size(GB)"; Expression={[math]::Round($_.Capacity/1GB, 2)}},
    Speed, MemoryType -AutoSize

# 2. Current Memory Usage
Write-Host "`n[2] CURRENT MEMORY USAGE" -ForegroundColor Yellow
$OS = Get-CimInstance Win32_OperatingSystem
$TotalVisible = [math]::Round($OS.TotalVisibleMemorySize / 1MB, 2)
$FreeMemory = [math]::Round($OS.FreePhysicalMemory / 1MB, 2)
$UsedMemory = $TotalVisible - $FreeMemory
$UsagePercent = [math]::Round(($UsedMemory / $TotalVisible) * 100, 2)

Write-Host "Total Available: $TotalVisible GB"
Write-Host "Used: $UsedMemory GB ($UsagePercent%)" -ForegroundColor $(if($UsagePercent -gt 90){"Red"}elseif($UsagePercent -gt 80){"Yellow"}else{"Green"})
Write-Host "Free: $FreeMemory GB"

# 3. Memory Composition
Write-Host "`n[3] MEMORY COMPOSITION" -ForegroundColor Yellow
$PageFile = Get-CimInstance Win32_PageFileUsage
if ($PageFile) {
    Write-Host "PageFile Usage: $([math]::Round($PageFile.AllocatedBaseSize/1GB, 2)) GB"
}

$CacheMemory = Get-Counter "\Memory\Cache Bytes" -SampleInterval 1
if ($CacheMemory) {
    $CacheMB = [math]::Round($CacheMemory.CounterSamples.CookedValue / 1MB, 2)
    Write-Host "Cached Memory: $CacheMB MB"
}

# 4. Top Memory Processes
Write-Host "`n[4] TOP MEMORY PROCESSES" -ForegroundColor Yellow
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 20 |
    Format-Table ProcessName, Id, 
        @{Name="WorkingSet(MB)"; Expression={[math]::Round($_.WorkingSet/1MB, 2)}},
        @{Name="Private(MB)"; Expression={[math]::Round($_.PrivateMemorySize/1MB, 2)}},
        CPU -AutoSize

# 5. Memory Leak Detection
Write-Host "`n[5] MEMORY LEAK DETECTION" -ForegroundColor Yellow
$HighMemoryProcesses = Get-Process | Where-Object { $_.WorkingSet -gt 500MB }
if ($HighMemoryProcesses.Count -gt 10) {
    Write-Host "  Multiple high-memory processes detected" -ForegroundColor Yellow
} else {
    Write-Host " Memory usage distribution normal" -ForegroundColor Green
}

# 6. Performance Recommendations
Write-Host "`n[6] MEMORY RECOMMENDATIONS" -ForegroundColor Yellow
if ($UsagePercent -gt 90) {
    Write-Host " CRITICAL: High memory usage" -ForegroundColor Red
    Write-Host "   - Close unnecessary applications" -ForegroundColor White
    Write-Host "   - Consider adding more RAM" -ForegroundColor White
    Write-Host "   - Check for memory leaks" -ForegroundColor White
} elseif ($UsagePercent -gt 80) {
    Write-Host "  WARNING: Memory usage high" -ForegroundColor Yellow
    Write-Host "   - Monitor memory usage" -ForegroundColor White
} else {
    Write-Host " Memory usage optimal" -ForegroundColor Green
}

Write-Host "`n=== RAM DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan

# =====================================================================
# 7. JSON EXPORT FOR PYTHON / LLM INTEGRATION
# =====================================================================
# Ambil 5 proses teratas untuk menghemat context window LLM
$Top5MemoryProcs = @()
if ($null -ne $HighMemoryProcesses -or $null -ne (Get-Process)) {
    $TopProcs = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5
    foreach ($P in $TopProcs) {
        $Top5MemoryProcs += [ordered]@{
            "ProcessName"  = $P.ProcessName
            "WorkingSetMB" = [math]::Round($P.WorkingSet / 1MB, 2)
        }
    }
}

$DiagnosticResult = [ordered]@{
    "TotalInstalledGB"    = if ($null -ne $TotalRAM) { [math]::Round($TotalRAM, 2) } else { 0 }
    "TotalAvailableGB"    = if ($null -ne $TotalVisible) { $TotalVisible } else { 0 }
    "UsedMemoryGB"        = if ($null -ne $UsedMemory) { $UsedMemory } else { 0 }
    "FreeMemoryGB"        = if ($null -ne $FreeMemory) { $FreeMemory } else { 0 }
    "UsagePercent"        = if ($null -ne $UsagePercent) { $UsagePercent } else { 0 }
    "PageFileGB"          = if ($null -ne $PageFile) { [math]::Round($PageFile.AllocatedBaseSize/1GB, 2) } else { 0 }
    "CacheMB"             = if ($null -ne $CacheMB) { $CacheMB } else { 0 }
    "HighMemProcessCount" = if ($null -ne $HighMemoryProcesses) { @($HighMemoryProcesses).Count } else { 0 }
    "TopProcesses"        = $Top5MemoryProcs
    "Status"              = if ($UsagePercent -gt 90) { "Critical" } elseif ($UsagePercent -gt 80) { "Warning" } else { "Optimal" }
}

# Convert to JSON and output it as a pure string
$JsonOutput = $DiagnosticResult | ConvertTo-Json -Depth 3 -Compress
Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"