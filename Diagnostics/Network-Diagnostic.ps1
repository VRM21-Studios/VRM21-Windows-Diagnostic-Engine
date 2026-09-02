# =====================================================================
# NETWORK DETAILED DIAGNOSTIC TOOL - WITH TUNING AUDIT
# =====================================================================

Write-Host "=== NETWORK DETAILED DIAGNOSTIC & TUNING AUDIT ===" -ForegroundColor Cyan

# 1. NETWORK ADAPTERS COMPREHENSIVE INFO
Write-Host "`n[1] NETWORK ADAPTERS DETAILED INFORMATION" -ForegroundColor Yellow

# Active adapters dengan info lengkap
Write-Host "`n[a] ACTIVE NETWORK ADAPTERS:" -ForegroundColor White
$ActiveAdapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
if ($ActiveAdapters) {
    $ActiveAdapters | Select-Object Name, InterfaceDescription, LinkSpeed, Status, 
        @{Name="MacAddress";Expression={$_.MacAddress}} | Format-Table -AutoSize
} else {
    Write-Host "No active network adapters found" -ForegroundColor Red
}

# DNS Settings untuk semua adapter
Write-Host "`n[b] DNS SERVER CONFIGURATION:" -ForegroundColor White
$DNSSettings = Get-DnsClientServerAddress | Where-Object {$_.ServerAddresses}
if ($DNSSettings) {
    $DNSSettings | Select-Object InterfaceAlias, ServerAddresses | Format-Table -AutoSize
} else {
    Write-Host "No DNS servers configured" -ForegroundColor Yellow
}

# 2. TCP/IP STACK TUNING AUDIT
Write-Host "`n[2] TCP/IP STACK TUNING AUDIT" -ForegroundColor Yellow

$TCPGlobal = netsh int tcp show global
Write-Host "Current TCP Global Settings:" -ForegroundColor Cyan

$TuningChecks = @{
    "ECN Capability" = @{
        Pattern = "ECN Capability\s*:\s*enabled"
        Recommended = "enabled"
        Description = "Explicit Congestion Notification"
    }
    "RFC 1323 Timestamps" = @{
        Pattern = "RFC 1323 Timestamps\s*:\s*enabled" 
        Recommended = "enabled"
        Description = "TCP timestamps for better RTT estimation"
    }
    "Receive Window Auto-Tuning" = @{
        Pattern = "Receive Window Auto-Tuning Level\s*:\s*normal"
        Recommended = "normal" 
        Description = "Auto-tuning for better throughput"
    }
    "Receive Segment Coalescing" = @{
        Pattern = "Receive Segment Coalescing State\s*:\s*disabled"
        Recommended = "disabled"
        Description = "RSC - better disabled for low latency"
    }
    "Receive-Side Scaling" = @{
        Pattern = "Receive-Side Scaling State\s*:\s*enabled"
        Recommended = "enabled"
        Description = "RSS - enables multi-core processing"
    }
    "Congestion Control" = @{
        Pattern = "Congestion Control Provider\s*:\s*ctcp"
        Recommended = "ctcp"
        Description = "Compound TCP for high-speed networks"
    }
}

$TuningScore = 100
$TuningIssues = @()

foreach ($Check in $TuningChecks.GetEnumerator()) {
    $Key = $Check.Key
    $Config = $Check.Value
    
    if ($TCPGlobal -match $Config.Pattern) {
        Write-Host "[OK]   $Key : $($Config.Recommended)" -ForegroundColor Green
        Write-Host "       $($Config.Description)" -ForegroundColor Gray
    } else {
        Write-Host "[WARN] $Key : Not $($Config.Recommended)" -ForegroundColor Red
        Write-Host "       $($Config.Description)" -ForegroundColor Gray
        $TuningScore -= 15
        $TuningIssues += "$Key should be $($Config.Recommended)"
    }
}

Write-Host "`nTCP Tuning Score: $TuningScore/100" -ForegroundColor $(if($TuningScore -ge 80){"Green"}elseif($TuningScore -ge 60){"Yellow"}else{"Red"})

# 3. NIC ADVANCED PROPERTIES AUDIT
Write-Host "`n[3] NIC ADVANCED PROPERTIES AUDIT" -ForegroundColor Yellow

# Cari adapter Ethernet utama
$EthernetAdapter = Get-NetAdapter | Where-Object {
    $_.InterfaceDescription -match "Ethernet|Gigabit|ASIX" -and $_.Status -eq "Up"
} | Select-Object -First 1

if ($EthernetAdapter) {
    Write-Host "Auditing adapter: $($EthernetAdapter.Name)" -ForegroundColor Cyan
    
    $AdvancedProps = Get-NetAdapterAdvancedProperty -Name $EthernetAdapter.Name -ErrorAction SilentlyContinue
    if ($AdvancedProps) {
        Write-Host "`nAll Advanced Properties:" -ForegroundColor White
        $AdvancedProps | Select-Object DisplayName, DisplayValue, RegistryKeyword | Format-Table -AutoSize
        
        # Important tuning parameters
        Write-Host "`n--- IMPORTANT TUNING PARAMETERS ---" -ForegroundColor Cyan
        
        $CriticalSettings = @(
            @{Name="Interrupt Moderation Rate"; Optimal="High"; Description="Reduces CPU usage for packet processing"},
            @{Name="Green Ethernet"; Optimal="Disabled"; Description="Saves power but may reduce performance"},
            @{Name="Flow Control"; Optimal="Rx & Tx Enabled"; Description="Prevents packet loss on congested networks"},
            @{Name="Jumbo Packet"; Optimal="Disabled"; Description="MTU size - typically best disabled"},
            @{Name="Receive Side Scaling"; Optimal="Enabled"; Description="Enables multi-core network processing"},
            @{Name="Receive Buffers"; Optimal="1024+"; Description="Higher values better for high throughput"}
        )
        
        foreach ($Setting in $CriticalSettings) {
            $Prop = $AdvancedProps | Where-Object {$_.DisplayName -eq $Setting.Name}
            if ($Prop) {
                $Status = if ($Prop.DisplayValue -eq $Setting.Optimal -or 
                             ($Setting.Name -eq "Receive Buffers" -and [int]$Prop.DisplayValue -ge 1024)) {
                    "OK"
                } else {
                    "WARN"
                }
                
                $Color = if ($Status -eq "OK") { "Green" } else { "Yellow" }
                Write-Host "[$Status] $($Setting.Name) : $($Prop.DisplayValue)" -ForegroundColor $Color
                Write-Host "        Optimal: $($Setting.Optimal) - $($Setting.Description)" -ForegroundColor Gray
            }
        }
        
        # Highlight specific values dari skrip lama Anda
        $Moderation = ($AdvancedProps | Where-Object {$_.DisplayName -match "Interrupt Moderation"}).DisplayValue
        $GreenEth = ($AdvancedProps | Where-Object {$_.DisplayName -match "Green Ethernet"}).DisplayValue
        
        Write-Host "`n--- YOUR CURRENT TUNING ---" -ForegroundColor Cyan
        Write-Host "Interrupt Moderation Rate : $Moderation" -ForegroundColor White
        Write-Host "Green Ethernet            : $GreenEth" -ForegroundColor White
        
    } else {
        Write-Host "No advanced properties available for this adapter" -ForegroundColor Yellow
    }
} else {
    Write-Host "No active Ethernet adapter found for advanced properties audit" -ForegroundColor Yellow
}

# 4. NETWORK PERFORMANCE MONITORING
Write-Host "`n[4] NETWORK PERFORMANCE & STATISTICS" -ForegroundColor Yellow

# Adapter statistics
Write-Host "`n[a] NETWORK ADAPTER STATISTICS:" -ForegroundColor White
$AdapterStats = Get-NetAdapterStatistics | Where-Object {$_.ReceivedBytes -gt 0 -or $_.SentBytes -gt 0}
if ($AdapterStats) {
    $AdapterStats | Select-Object Name,
        @{Name="Received(MB)"; Expression={[math]::Round($_.ReceivedBytes/1MB, 2)}},
        @{Name="Sent(MB)"; Expression={[math]::Round($_.SentBytes/1MB, 2)}},
        @{Name="ReceivedPackets"; Expression={$_.ReceivedUnicastPackets}},
        @{Name="SentPackets"; Expression={$_.SentUnicastPackets}},
        @{Name="Errors"; Expression={$_.ReceivedErrors + $_.SentErrors}} | Format-Table -AutoSize
}

# Active connections analysis
Write-Host "`n[b] ACTIVE NETWORK CONNECTIONS ANALYSIS:" -ForegroundColor White
$Connections = Get-NetTCPConnection | Where-Object {$_.State -eq "Established"} | 
    Group-Object OwningProcess

if ($Connections) {
    $ConnectionSummary = $Connections | ForEach-Object {
        $Process = Get-Process -Id $_.Name -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            ProcessName = if($Process){$Process.ProcessName}else{"Unknown"}
            ProcessId = $_.Name
            Connections = $_.Count
            RemotePorts = ($_.Group.RemotePort | Sort-Object -Unique | Select-Object -First 3) -join ", "
        }
    } | Sort-Object Connections -Descending | Select-Object -First 10
    
    $ConnectionSummary | Format-Table -AutoSize
    
    # High connection alert
    $HighConnections = $ConnectionSummary | Where-Object {$_.Connections -gt 20}
    if ($HighConnections) {
        Write-Host "  High connection count detected:" -ForegroundColor Yellow
        $HighConnections | Format-Table -AutoSize
    }
} else {
    Write-Host "No established connections" -ForegroundColor Gray
}

# 5. WIRELESS NETWORK AUDIT (jika ada)
Write-Host "`n[5] WIRELESS NETWORK AUDIT" -ForegroundColor Yellow

try {
    $WifiInfo = netsh wlan show interfaces | Out-String
    if ($WifiInfo -match "SSID") {
        Write-Host "Wireless Adapter Information:" -ForegroundColor White
        
        # Extract important WiFi info
        $SSID = if ($WifiInfo -match "SSID\s*:\s*(.+)") { $Matches[1].Trim() } else { "Not connected" }
        $Signal = if ($WifiInfo -match "Signal\s*:\s*(\d+)%") { "$($Matches[1])%" } else { "Unknown" }
        $Radio = if ($WifiInfo -match "Radio type\s*:\s*(.+)") { $Matches[1].Trim() } else { "Unknown" }
        $Channel = if ($WifiInfo -match "Channel\s*:\s*(\d+)") { $Matches[1] } else { "Unknown" }
        $ReceiveRate = if ($WifiInfo -match "Receive rate \(Mbps\)\s*:\s*(\d+)") { "$($Matches[1]) Mbps" } else { "Unknown" }
        $TransmitRate = if ($WifiInfo -match "Transmit rate \(Mbps\)\s*:\s*(\d+)") { "$($Matches[1]) Mbps" } else { "Unknown" }
        
        Write-Host "  SSID         : $SSID" -ForegroundColor Cyan
        Write-Host "  Signal       : $Signal" -ForegroundColor $(if($Signal -match "(\d+)%" -and $Matches[1] -gt 70){"Green"}elseif($Matches[1] -gt 50){"Yellow"}else{"Red"})
        Write-Host "  Radio Type   : $Radio"
        Write-Host "  Channel      : $Channel"
        Write-Host "  Receive Rate : $ReceiveRate"
        Write-Host "  Transmit Rate: $TransmitRate"
    } else {
        Write-Host "No wireless adapters connected" -ForegroundColor Gray
    }
} catch {
    Write-Host "Wireless information unavailable" -ForegroundColor Gray
}

# 6. NETWORK TUNING RECOMMENDATIONS
Write-Host "`n[6] NETWORK TUNING RECOMMENDATIONS" -ForegroundColor Yellow

if ($TuningIssues) {
    Write-Host " RECOMMENDED TCP TUNING FIXES:" -ForegroundColor Cyan
    foreach ($Issue in $TuningIssues) {
        Write-Host "   • $Issue" -ForegroundColor White
    }
    
    Write-Host "`n QUICK TUNING COMMANDS (Run as Admin):" -ForegroundColor Cyan
    Write-Host "   netsh int tcp set global autotuninglevel=normal" -ForegroundColor White
    Write-Host "   netsh int tcp set global rsc=disabled" -ForegroundColor White
    Write-Host "   netsh int tcp set global congestionprovider=ctcp" -ForegroundColor White
}

# Performance tips berdasarkan findings
if ($EthernetAdapter -and $EthernetAdapter.LinkSpeed -match "1 Gbps") {
    Write-Host "`n GIGABIT ETHERNET OPTIMIZATION:" -ForegroundColor Cyan
    Write-Host "   • Ensure Jumbo Frames are disabled unless specifically configured" -ForegroundColor White
    Write-Host "   • Use Cat6 or better Ethernet cables" -ForegroundColor White
    Write-Host "   • Check switch/router for any port limitations" -ForegroundColor White
}

if ($WifiInfo -and $Signal -match "(\d+)%" -and $Matches[1] -lt 70) {
    Write-Host "`n WIFI SIGNAL OPTIMIZATION:" -ForegroundColor Cyan
    Write-Host "   • Consider moving closer to access point" -ForegroundColor White
    Write-Host "   • Check for interference from other devices" -ForegroundColor White
    Write-Host "   • Try different WiFi channels" -ForegroundColor White
}

# 7. FINAL NETWORK HEALTH SUMMARY
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host " NETWORK HEALTH SUMMARY" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

$NetworkHealthScore = 100

# Scoring adjustments
if (-not $ActiveAdapters) {
    $NetworkHealthScore -= 50
    Write-Host " CRITICAL: No active network adapters" -ForegroundColor Red
}

if ($TuningScore -lt 70) {
    $NetworkHealthScore -= 20
    Write-Host "  WARNING: TCP tuning needs optimization" -ForegroundColor Yellow
}

if ($HighConnections) {
    $NetworkHealthScore -= 10
    Write-Host "  WARNING: High connection counts detected" -ForegroundColor Yellow
}

# Display final score
Write-Host "`n NETWORK HEALTH SCORE: $NetworkHealthScore/100" -ForegroundColor $(
    if ($NetworkHealthScore -ge 80) { "Green" } 
    elseif ($NetworkHealthScore -ge 60) { "Yellow" } 
    else { "Red" }
)

if ($NetworkHealthScore -ge 80) {
    Write-Host " EXCELLENT! Network configuration is well-tuned!" -ForegroundColor Green
} elseif ($NetworkHealthScore -ge 60) {
    Write-Host "  GOOD! Some network optimizations possible." -ForegroundColor Yellow
} else {
    Write-Host " ATTENTION NEEDED! Network issues detected." -ForegroundColor Red
}

Write-Host "`n=== NETWORK DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan

# =====================================================================
# 8. JSON EXPORT FOR PYTHON / LLM INTEGRATION
# =====================================================================
$ActiveAdaptersCount = if ($null -ne $ActiveAdapters) { @($ActiveAdapters).Count } else { 0 }

$HighConnList = @()
if ($null -ne $HighConnections) {
    foreach ($hc in $HighConnections) {
        $HighConnList += [ordered]@{ 
            "Process"     = $hc.ProcessName
            "Connections" = $hc.Connections 
        }
    }
}

$DiagnosticResult = [ordered]@{
    "NetworkHealthScore"  = $NetworkHealthScore
    "TcpTuningScore"      = $TuningScore
    "ActiveAdaptersCount" = $ActiveAdaptersCount
    "TuningIssues"        = $TuningIssues
    "IsWifiConnected"     = if ($WifiInfo -match "SSID" -and $SSID -ne "Not connected") { $true } else { $false }
    "WifiSignalPct"       = if ($Signal -match "(\d+)%") { [int]$Matches[1] } else { 0 }
    "HighConnectionProcs" = $HighConnList
}

# Convert to JSON and output it as a pure string
$JsonOutput = $DiagnosticResult | ConvertTo-Json -Depth 3 -Compress
Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"