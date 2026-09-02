# =====================================================================
# SECURITY DETAILED DIAGNOSTIC TOOL
# Mode    : Read-Only Audit
# Purpose: Comprehensive security assessment for Windows systems
# =====================================================================

Write-Host "=== SECURITY DETAILED DIAGNOSTIC ===" -ForegroundColor Cyan

# Initialize security score and diagnostic findings.
$SecurityScore = 100
$SecurityIssues = @()
$SecurityWarnings = @()


# =====================================================================
# 1. WINDOWS DEFENDER STATUS
# =====================================================================
Write-Host "`n[1] WINDOWS DEFENDER COMPREHENSIVE STATUS" -ForegroundColor Yellow

try {
    $DefenderStatus = Get-MpComputerStatus

    if ($DefenderStatus) {
        Write-Host "Antivirus Enabled: $($DefenderStatus.AntivirusEnabled)" `
            -ForegroundColor $(if ($DefenderStatus.AntivirusEnabled) {
                "Green"
            }
            else {
                "Red"
            })

        Write-Host "Real-time Protection: $($DefenderStatus.RealTimeProtectionEnabled)" `
            -ForegroundColor $(if ($DefenderStatus.RealTimeProtectionEnabled) {
                "Green"
            }
            else {
                "Red"
            })

        Write-Host "Antispyware Enabled: $($DefenderStatus.AntispywareEnabled)" `
            -ForegroundColor $(if ($DefenderStatus.AntispywareEnabled) {
                "Green"
            }
            else {
                "Yellow"
            })

        Write-Host "Behavior Monitoring: $($DefenderStatus.BehaviorMonitorEnabled)" `
            -ForegroundColor $(if ($DefenderStatus.BehaviorMonitorEnabled) {
                "Green"
            }
            else {
                "Yellow"
            })

        if ($DefenderStatus.LastQuickScan) {
            Write-Host "Last Quick Scan: $($DefenderStatus.LastQuickScan)"
        }

        if ($DefenderStatus.LastFullScan) {
            Write-Host "Last Full Scan: $($DefenderStatus.LastFullScan)"
        }

        if ($DefenderStatus.LastSignatureUpdate) {
            $SigAge = (Get-Date) - $DefenderStatus.LastSignatureUpdate

            Write-Host "Signature Age: $($SigAge.Days) days" `
                -ForegroundColor $(if ($SigAge.Days -gt 7) {
                    "Red"
                }
                elseif ($SigAge.Days -gt 3) {
                    "Yellow"
                }
                else {
                    "Green"
                })
        }


        # Security score adjustments.
        if (
            -not $DefenderStatus.AntivirusEnabled -or
            -not $DefenderStatus.RealTimeProtectionEnabled
        ) {
            $SecurityScore -= 25
            $SecurityIssues += "Windows Defender is not fully enabled"
        }

        if (
            $DefenderStatus.LastSignatureUpdate -and
            (Get-Date).AddDays(-7) -gt $DefenderStatus.LastSignatureUpdate
        ) {
            $SecurityScore -= 10
            $SecurityWarnings += "Antivirus signatures are outdated (>7 days)"
        }
    }
}
catch {
    Write-Host "Windows Defender status unavailable." -ForegroundColor Red

    $SecurityScore -= 30
    $SecurityIssues += "Windows Defender status could not be accessed"
}


# =====================================================================
# 2. PROCESS SECURITY ANALYSIS
# =====================================================================
Write-Host "`n[2] PROCESS SECURITY ANALYSIS" -ForegroundColor Yellow

# Common Windows processes that are excluded from the heuristic check.
$SafeProcesses = @(
    "System",
    "Idle",
    "csrss",
    "wininit",
    "smss",
    "lsass",
    "lsm",
    "services",
    "winlogon",
    "svchost",
    "taskhostw",
    "explorer",
    "dwm",
    "SearchIndexer",
    "conhost",
    "RuntimeBroker",
    "fontdrvhost",
    "sihost",
    "ctfmon",
    "ApplicationFrameHost",
    "StartMenuExperienceHost",
    "TextInputHost",
    "SearchApp",
    "LockApp"
)


# Processes without company information and outside common system
# or program installation directories.
Write-Host "`n[a] PROCESSES WITHOUT COMPANY INFORMATION:" -ForegroundColor White

$SuspiciousProcesses = Get-Process |
    Where-Object {
        $_.Company -eq $null -and
        $_.ProcessName -notin $SafeProcesses -and
        $_.Path -notlike "$env:WINDIR\*" -and
        $_.Path -notlike "$env:ProgramFiles\*" -and
        $_.Path -notlike "$env:ProgramFiles(x86)\*"
    } |
    Sort-Object WorkingSet -Descending

if ($SuspiciousProcesses) {
    Write-Host "Found $($SuspiciousProcesses.Count) suspicious processes:" `
        -ForegroundColor Red

    $SuspiciousProcesses |
        Select-Object -First 10 ProcessName, Id,
            @{Name = "Memory(MB)"; Expression = {
                [math]::Round($_.WorkingSet / 1MB, 2)
            }},
            Path |
        Format-Table -AutoSize

    if ($SuspiciousProcesses.Count -gt 5) {
        $SecurityScore -= 20
        $SecurityIssues += "Multiple suspicious processes without company information"
    }
    else {
        $SecurityScore -= 10
        $SecurityWarnings += "Some processes have no company information"
    }
}
else {
    Write-Host "No suspicious processes detected." -ForegroundColor Green
}


# High-resource processes.
Write-Host "`n[b] HIGH RESOURCE PROCESSES:" -ForegroundColor White

$HighCPUProcesses = Get-Process |
    Sort-Object CPU -Descending |
    Select-Object -First 10

$HighMemoryProcesses = Get-Process |
    Sort-Object WorkingSet -Descending |
    Select-Object -First 10

Write-Host "Top 10 CPU Processes:" -ForegroundColor Cyan

$HighCPUProcesses |
    Format-Table ProcessName, Id, CPU,
        @{Name = "Memory(MB)"; Expression = {
            [math]::Round($_.WorkingSet / 1MB, 2)
        }} -AutoSize

Write-Host "Top 10 Memory Processes:" -ForegroundColor Cyan

$HighMemoryProcesses |
    Format-Table ProcessName, Id, CPU,
        @{Name = "Memory(MB)"; Expression = {
            [math]::Round($_.WorkingSet / 1MB, 2)
        }} -AutoSize


# =====================================================================
# 3. NETWORK SECURITY ANALYSIS
# =====================================================================
Write-Host "`n[3] NETWORK SECURITY ANALYSIS" -ForegroundColor Yellow


# Established network connections.
Write-Host "`n[a] ESTABLISHED NETWORK CONNECTIONS:" -ForegroundColor White

$Connections = Get-NetTCPConnection |
    Where-Object {
        $_.State -eq "Established"
    } |
    Group-Object OwningProcess

$ConnectionSummary = $Connections |
    ForEach-Object {
        $Process = Get-Process -Id $_.Name -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            ProcessName = if ($Process) {
                $Process.ProcessName
            }
            else {
                "Unknown"
            }

            ProcessId = $_.Name
            Connections = $_.Count
            RemotePorts = (
                $_.Group.RemotePort |
                    Sort-Object -Unique
            ) -join ", "
        }
    } |
    Sort-Object Connections -Descending

if ($ConnectionSummary) {
    $ConnectionSummary |
        Format-Table -AutoSize

    # Flag processes with a high number of established connections.
    $HighConnectionProcesses = $ConnectionSummary |
        Where-Object {
            $_.Connections -gt 15
        }

    if ($HighConnectionProcesses) {
        Write-Host "High connection count detected:" -ForegroundColor Red

        $HighConnectionProcesses |
            Format-Table -AutoSize

        $SecurityScore -= 15
        $SecurityIssues += "Processes with a high number of network connections"
    }
}
else {
    Write-Host "No established connections." -ForegroundColor Green
}


# Suspicious port heuristic.
Write-Host "`n[b] SUSPICIOUS PORTS CHECK:" -ForegroundColor White

$SuspiciousPorts = @(
    4444,
    5555,
    6666,
    6667,
    1337,
    31337,
    12345,
    12346,
    20034,
    27374,
    9989,
    9999
)

$FoundSuspiciousPorts = Get-NetTCPConnection |
    Where-Object {
        $SuspiciousPorts -contains $_.LocalPort -or
        $SuspiciousPorts -contains $_.RemotePort
    }

if ($FoundSuspiciousPorts) {
    Write-Host "SUSPICIOUS PORTS DETECTED:" -ForegroundColor Red

    $FoundSuspiciousPorts |
        Format-Table LocalAddress,
            LocalPort,
            RemoteAddress,
            RemotePort,
            State,
            OwningProcess -AutoSize

    $SecurityScore -= 25
    $SecurityIssues += "Network connections using ports from the suspicious-port list were detected"
}
else {
    Write-Host "No suspicious ports detected." -ForegroundColor Green
}


# =====================================================================
# 4. AUTOSTART AND PERSISTENCE ANALYSIS
# =====================================================================
Write-Host "`n[4] AUTOSTART AND PERSISTENCE LOCATIONS" -ForegroundColor Yellow

$StartupLocations = @(
    @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        Description = "Local Machine Run"
    },
    @{
        Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        Description = "Current User Run"
    },
    @{
        Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
        Description = "32-bit Machine Run"
    },
    @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        Description = "Machine Run Once"
    },
    @{
        Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        Description = "User Run Once"
    }
)

$StartupCount = 0

foreach ($Location in $StartupLocations) {
    Write-Host "`n$($Location.Description):" -ForegroundColor Cyan

    try {
        $Entries = Get-ItemProperty $Location.Path -ErrorAction Stop |
            Get-Member -MemberType NoteProperty |
            Where-Object {
                $_.Name -notlike "PS*"
            }

        if ($Entries) {
            $StartupCount += $Entries.Count

            foreach ($Entry in $Entries) {
                $Value = (
                    Get-ItemProperty $Location.Path
                ).$($Entry.Name)

                Write-Host "  $($Entry.Name) : $Value" `
                    -ForegroundColor White
            }
        }
        else {
            Write-Host "  No entries." -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  No entries or access denied." `
            -ForegroundColor Gray
    }
}

Write-Host "`nTotal startup entries: $StartupCount" `
    -ForegroundColor $(if ($StartupCount -gt 20) {
        "Red"
    }
    elseif ($StartupCount -gt 10) {
        "Yellow"
    }
    else {
        "Green"
    })

if ($StartupCount -gt 20) {
    $SecurityScore -= 10
    $SecurityWarnings += "High number of startup entries"
}


# =====================================================================
# 5. FILE SYSTEM SECURITY CHECK
# =====================================================================
Write-Host "`n[5] FILE SYSTEM SECURITY CHECK" -ForegroundColor Yellow


# Recently modified executable files in selected system directories.
Write-Host "`n[a] RECENTLY MODIFIED EXECUTABLES (LAST 7 DAYS):" `
    -ForegroundColor White

$SystemPaths = @(
    "C:\Windows\System32",
    "C:\Windows\Temp",
    "C:\Users\$env:USERNAME\AppData\Local\Temp",
    "C:\Windows\SysWOW64"
)

$RecentExecutables = @()

foreach ($Path in $SystemPaths) {
    if (Test-Path $Path) {
        Write-Host "Scanning: $Path" -ForegroundColor Cyan

        $Files = Get-ChildItem $Path `
            -Filter "*.exe" `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.LastWriteTime -gt (Get-Date).AddDays(-7)
            } |
            Select-Object Name,
                @{Name = "Size(MB)"; Expression = {
                    [math]::Round($_.Length / 1MB, 2)
                }},
                Directory,
                LastWriteTime

        if ($Files) {
            $RecentExecutables += $Files
            $Files | Format-Table -AutoSize
        }
        else {
            Write-Host "  No recent executables." -ForegroundColor Gray
        }
    }
}

if ($RecentExecutables.Count -gt 5) {
    $SecurityScore -= 15
    $SecurityIssues += "Multiple recently modified executables detected in selected system directories"
}


# Browser extensions.
Write-Host "`n[b] BROWSER EXTENSIONS CHECK:" -ForegroundColor White

$BrowserPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions",
    "$env:APPDATA\Mozilla\Firefox\Profiles"
)

foreach ($Path in $BrowserPaths) {
    if (Test-Path $Path) {
        Write-Host "`nExtensions in: $Path" -ForegroundColor Cyan

        $Extensions = Get-ChildItem $Path `
            -Directory `
            -ErrorAction SilentlyContinue |
            Select-Object Name, LastWriteTime

        if ($Extensions) {
            $Extensions | Format-Table -AutoSize
        }
        else {
            Write-Host "  No extensions found." -ForegroundColor Gray
        }
    }
}


# =====================================================================
# 6. SYSTEM SECURITY CONFIGURATION
# =====================================================================
Write-Host "`n[6] SYSTEM SECURITY CONFIGURATION" -ForegroundColor Yellow


# UAC configuration.
try {
    $UAC = Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        -Name "EnableLUA" `
        -ErrorAction SilentlyContinue

    if ($UAC.EnableLUA -eq 1) {
        Write-Host "UAC (User Account Control): Enabled" `
            -ForegroundColor Green
    }
    else {
        Write-Host "UAC (User Account Control): Disabled" `
            -ForegroundColor Red

        $SecurityScore -= 15
        $SecurityIssues += "UAC is disabled"
    }
}
catch {
    Write-Host "UAC: Setting not found" -ForegroundColor Yellow
}


# System uptime.
Write-Host "`n[c] SYSTEM UPTIME:" -ForegroundColor White

try {
    $LastBoot = (
        Get-CimInstance Win32_OperatingSystem
    ).LastBootUpTime

    $Uptime = (Get-Date) - $LastBoot

    Write-Host "System Uptime: $($Uptime.Days) days, $($Uptime.Hours) hours, $($Uptime.Minutes) minutes" `
        -ForegroundColor $(if ($Uptime.Days -gt 30) {
            "Yellow"
        }
        else {
            "Green"
        })

    if ($Uptime.Days -gt 30) {
        $SecurityWarnings += "System has been running for over 30 days; consider restarting"
    }
}
catch {
    Write-Host "Uptime information unavailable." -ForegroundColor Gray
}


# Recent Security event log entries.
Write-Host "`n[d] RECENT SECURITY EVENTS (LAST 24 HOURS):" `
    -ForegroundColor White

try {
    $SecurityEvents = Get-WinEvent `
        -FilterHashtable @{
            LogName = "Security"
            StartTime = (Get-Date).AddHours(-24)
        } `
        -MaxEvents 5 `
        -ErrorAction SilentlyContinue

    if ($SecurityEvents) {
        $SecurityEvents |
            Select-Object TimeCreated,
                Id,
                LevelDisplayName,
                @{Name = "Message"; Expression = {
                    $_.Message.Substring(
                        0,
                        [math]::Min(100, $_.Message.Length)
                    )
                }} |
            Format-Table -AutoSize
    }
    else {
        Write-Host "No recent security events found." `
            -ForegroundColor Green
    }
}
catch {
    Write-Host "Security event log inaccessible." `
        -ForegroundColor Yellow
}


# =====================================================================
# 7. FINAL SECURITY ASSESSMENT
# =====================================================================
Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
Write-Host " FINAL SECURITY ASSESSMENT" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan


# Additional scoring adjustments.
if ($RecentExecutables.Count -gt 10) {
    $SecurityScore -= 10
}

if ($StartupCount -gt 25) {
    $SecurityScore -= 5
}


# Ensure the score does not fall below zero.
$SecurityScore = [math]::Max(0, $SecurityScore)


# Display final score.
Write-Host "`n FINAL SECURITY SCORE: $SecurityScore/100" `
    -ForegroundColor $(
        if ($SecurityScore -ge 80) {
            "Green"
        }
        elseif ($SecurityScore -ge 60) {
            "Yellow"
        }
        else {
            "Red"
        }
    )


# Display security status.
if ($SecurityScore -ge 80) {
    Write-Host " EXCELLENT! System security is in good condition." `
        -ForegroundColor Green
}
elseif ($SecurityScore -ge 60) {
    Write-Host " GOOD! Some security improvements may be needed." `
        -ForegroundColor Yellow
}
else {
    Write-Host " POOR! Security review is recommended." `
        -ForegroundColor Red
}


# Display issues and warnings.
if ($SecurityIssues) {
    Write-Host "`n CRITICAL ISSUES:" -ForegroundColor Red

    foreach ($Issue in $SecurityIssues) {
        Write-Host "   • $Issue" -ForegroundColor Red
    }
}

if ($SecurityWarnings) {
    Write-Host "`n WARNINGS:" -ForegroundColor Yellow

    foreach ($Warning in $SecurityWarnings) {
        Write-Host "   • $Warning" -ForegroundColor Yellow
    }
}

if (-not $SecurityIssues -and -not $SecurityWarnings) {
    Write-Host "`n No security issues detected!" -ForegroundColor Green
}


# Security recommendations.
Write-Host "`n SECURITY RECOMMENDATIONS:" -ForegroundColor Cyan

if ($SecurityScore -lt 80) {
    if ($SecurityIssues -contains "Windows Defender is not fully enabled") {
        Write-Host "   • Enable Windows Defender real-time protection" `
            -ForegroundColor White
    }

    if (
        $SecurityIssues -contains
        "Multiple suspicious processes without company information"
    ) {
        Write-Host "   • Investigate suspicious processes and verify their origin" `
            -ForegroundColor White
    }

    if (
        $SecurityIssues -contains
        "Network connections using ports from the suspicious-port list were detected"
    ) {
        Write-Host "   • Investigate network connections using flagged ports" `
            -ForegroundColor White
    }

    if ($SecurityWarnings -contains "High number of startup entries") {
        Write-Host "   • Review and clean up unnecessary startup entries" `
            -ForegroundColor White
    }
}
else {
    Write-Host "   • Continue regular security monitoring" `
        -ForegroundColor White

    Write-Host "   • Keep Windows and antivirus components updated" `
        -ForegroundColor White

    Write-Host "   • Practice safe browsing habits" `
        -ForegroundColor White
}


Write-Host "`n=== SECURITY DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan


# =====================================================================
# 8. JSON EXPORT FOR PYTHON / LLM INTEGRATION
# =====================================================================
$SuspiciousProcessCount = if ($null -ne $SuspiciousProcesses) {
    @($SuspiciousProcesses).Count
}
else {
    0
}

$SuspiciousPortCount = if ($null -ne $FoundSuspiciousPorts) {
    @($FoundSuspiciousPorts).Count
}
else {
    0
}

$UacEnabled = if (
    $null -ne $UAC -and
    $UAC.EnableLUA -eq 1
) {
    $true
}
else {
    $false
}

$DefEnabled = if (
    $null -ne $DefenderStatus -and
    $DefenderStatus.AntivirusEnabled
) {
    $true
}
else {
    $false
}


$DiagnosticResult = [ordered]@{
    "SecurityScore"          = $SecurityScore
    "DefenderEnabled"        = $DefEnabled
    "SuspiciousProcessCount" = $SuspiciousProcessCount
    "SuspiciousPortCount"    = $SuspiciousPortCount
    "TotalStartupEntries"    = $StartupCount
    "UacEnabled"             = $UacEnabled
    "Issues"                 = $SecurityIssues
    "Warnings"               = $SecurityWarnings
}


# Convert the diagnostic result to a compact JSON string.
$JsonOutput = $DiagnosticResult |
    ConvertTo-Json -Depth 3 -Compress

Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"
