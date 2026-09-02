# =====================================================================
# SERVICE AND BLOATWARE DETAILED DIAGNOSTIC TOOL
# Mode    : Read-Only Audit
# Purpose : Identify unnecessary services, bloatware, and startup clutter
# =====================================================================

Write-Host "=== SERVICE AND BLOATWARE DETAILED DIAGNOSTIC ===" -ForegroundColor Cyan

$SvcScore = 100
$SvcIssues = @()
$SvcWarnings = @()


# =====================================================================
# 1. RUNNING SERVICE ANALYSIS
# =====================================================================
Write-Host "`n[1] RUNNING SERVICES ANALYSIS" -ForegroundColor Yellow

$AllServices = Get-Service
$RunningServices = $AllServices | Where-Object {
    $_.Status -eq "Running"
}

Write-Host "Total Services   : $($AllServices.Count)"
Write-Host "Running Services : $($RunningServices.Count)"

if ($RunningServices.Count -gt 150) {
    $SvcWarnings += "High number of running services (>150)"
    $SvcScore -= 10
}


# High-CPU service-related processes.
Write-Host "`n[a] HIGH CPU/RAM SERVICE PROCESSES:" -ForegroundColor White

$HighSvc = Get-Process |
    Sort-Object CPU -Descending |
    Select-Object -First 15

$HighSvc |
    Format-Table ProcessName, Id,
        @{Name = "CPU"; Expression = {
            [math]::Round($_.CPU, 2)
        }},
        @{Name = "RAM(MB)"; Expression = {
            [math]::Round($_.WorkingSet / 1MB, 2)
        }} -AutoSize


# Flag processes with relatively high CPU time or memory usage.
foreach ($p in $HighSvc) {
    if ($p.CPU -gt 200 -or $p.WorkingSet -gt 800MB) {
        $SvcWarnings += "Process $($p.ProcessName) has high CPU/RAM usage"
        $SvcScore -= 5
    }
}


# =====================================================================
# 2. POTENTIALLY UNNECESSARY SERVICES
# =====================================================================
Write-Host "`n[2] POTENTIALLY UNNECESSARY SERVICE CHECK" -ForegroundColor Yellow

# Common services that may be unnecessary depending on system usage.
$CommonBloatServices = @(
    "DiagTrack",                # Telemetry
    "WSearch",                  # Windows Search indexing
    "Fax",                      # Fax service
    "PrintNotify",              # Print notifications
    "MapsBroker",               # Offline Maps
    "XblAuthManager",           # Xbox
    "XblGameSave",
    "XboxGipSvc",
    "XboxNetApiSvc",
    "WMPNetworkSvc",            # Windows Media Player Network Sharing
    "RetailDemo",               # Retail Demo
    "WerSvc"                    # Windows Error Reporting
)

$FoundBloatServices = $RunningServices |
    Where-Object {
        $CommonBloatServices -contains $_.Name
    }

if ($FoundBloatServices) {
    Write-Host "Potentially unnecessary services found:" -ForegroundColor Red

    $FoundBloatServices |
        Format-Table Name, Status, DisplayName -AutoSize

    $SvcScore -= ($FoundBloatServices.Count * 2)
    $SvcWarnings += "Potentially unnecessary background services are running"
}
else {
    Write-Host "No listed potentially unnecessary services are running." `
        -ForegroundColor Green
}


# =====================================================================
# 3. STARTUP PROGRAM ANALYSIS
# =====================================================================
Write-Host "`n[3] STARTUP PROGRAMS" -ForegroundColor Yellow

$StartupList = Get-CimInstance Win32_StartupCommand |
    Select-Object Name, Command, Location

if ($StartupList) {
    Write-Host "Startup entries: $($StartupList.Count)"

    $StartupList |
        Format-Table -AutoSize

    if ($StartupList.Count -gt 20) {
        $SvcWarnings += "High number of startup applications (>20)"
        $SvcScore -= 10
    }
}
else {
    Write-Host "No startup entries found." -ForegroundColor Green
}


# =====================================================================
# 4. SCHEDULED TASK AUDIT
# =====================================================================
Write-Host "`n[4] SCHEDULED TASKS (AUTORUN)" -ForegroundColor Yellow

$Tasks = Get-ScheduledTask |
    Where-Object {
        $_.State -eq "Ready" -or $_.State -eq "Running"
    }

$AutoTasks = $Tasks |
    Where-Object {
        $_.Triggers |
            Where-Object {
                $_.Enabled -eq $true
            }
    }

Write-Host "Auto-triggered tasks: $($AutoTasks.Count)"

if ($AutoTasks.Count -gt 50) {
    $SvcWarnings += "High number of auto-triggered scheduled tasks (>50)"
    $SvcScore -= 10
}


# Identify commonly associated telemetry or background tasks.
$NoisyTasks = $AutoTasks |
    Where-Object {
        $_.TaskName -match "Telemetry|Maps|CEIP|Xbox|OneDrive"
    }

if ($NoisyTasks) {
    Write-Host "`nTelemetry/Background Tasks:" -ForegroundColor Yellow

    $NoisyTasks |
        Format-Table TaskName, TaskPath, State -AutoSize

    $SvcScore -= 5
}


# =====================================================================
# 5. APPX APPLICATION DETECTION
# =====================================================================
Write-Host "`n[5] APPX APPLICATION DETECTION" -ForegroundColor Yellow

$Appx = Get-AppxPackage

# Common applications that may be considered unnecessary depending on
# user requirements or system configuration.
$CommonBloatAppx = @(
    "Microsoft.XboxApp",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.YourPhone",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.3DBuilder",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.OneConnect",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.BingWeather",
    "Microsoft.BingNews",
    "Microsoft.WindowsMaps",
    "Clipchamp.Clipchamp",
    "Disney",
    "TikTok",
    "Spotify",
    "Dolby",
    "Trial"                    # OEM preloads
)

$FoundAppBloat = $Appx |
    Where-Object {
        $CommonBloatAppx -contains $_.Name
    }

if ($FoundAppBloat) {
    Write-Host "Listed AppX applications detected:" -ForegroundColor Red

    $FoundAppBloat |
        Select-Object Name, PackageFullName |
        Format-Table -AutoSize

    $SvcWarnings += "Potentially unnecessary AppX applications installed"
    $SvcScore -= ($FoundAppBloat.Count * 1.5)
}
else {
    Write-Host "No listed AppX applications detected." -ForegroundColor Green
}


# =====================================================================
# 6. BACKGROUND PROCESS RESOURCE USAGE
# =====================================================================
Write-Host "`n[6] BACKGROUND RESOURCE USAGE" -ForegroundColor Yellow

$BackgroundHogs = Get-Process |
    Where-Object {
        $_.ProcessName -match "chrome|edge|teams|discord|onedrive|steam" -and
        $_.WorkingSet -gt 300MB
    }

if ($BackgroundHogs) {
    Write-Host "High-memory background processes:" -ForegroundColor Yellow

    $BackgroundHogs |
        Select-Object ProcessName, Id,
            @{Name = "RAM(MB)"; Expression = {
                [math]::Round($_.WorkingSet / 1MB, 2)
            }} |
        Format-Table -AutoSize

    $SvcWarnings += "Some background applications are consuming high memory"
    $SvcScore -= ($BackgroundHogs.Count * 2)
}
else {
    Write-Host "No heavy background applications detected." -ForegroundColor Green
}


# =====================================================================
# 7. FINAL SERVICE AND BLOAT HEALTH SCORE
# =====================================================================
Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
Write-Host " SERVICE AND BLOAT HEALTH SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

Write-Host "`nFinal Score: $SvcScore/100" -ForegroundColor `
    $(if ($SvcScore -ge 80) {
        "Green"
    }
    elseif ($SvcScore -ge 60) {
        "Yellow"
    }
    else {
        "Red"
    })


if ($SvcIssues) {
    Write-Host "`n CRITICAL ISSUES:" -ForegroundColor Red

    $SvcIssues |
        ForEach-Object {
            Write-Host "  • $_"
        }
}


if ($SvcWarnings) {
    Write-Host "`n WARNINGS:" -ForegroundColor Yellow

    $SvcWarnings |
        ForEach-Object {
            Write-Host "  • $_"
        }
}


Write-Host "`n RECOMMENDATIONS:" -ForegroundColor Cyan

if ($SvcScore -ge 80) {
    Write-Host "  • System appears to have no major service or background-process issues."
    Write-Host "  • Review Xbox and telemetry-related services if they are not required."
}
elseif ($SvcScore -ge 60) {
    Write-Host "  • Review startup applications and disable unnecessary entries."
    Write-Host "  • Review unused AppX applications such as Weather, News, Xbox, or Maps."
    Write-Host "  • Review WSearch if Windows Search indexing is not required."
}
else {
    Write-Host "  • Multiple service or background-resource indicators were detected."
    Write-Host "  • Review startup applications, AppX packages, scheduled tasks, and optional services."
}

Write-Host "`n=== SERVICE AND BLOAT DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan


# =====================================================================
# 8. JSON EXPORT FOR PYTHON / LLM INTEGRATION
# =====================================================================
$BloatServicesList = @()

if ($null -ne $FoundBloatServices) {
    $BloatServicesList = $FoundBloatServices |
        Select-Object -ExpandProperty Name
}


$BloatAppxList = @()

if ($null -ne $FoundAppBloat) {
    $BloatAppxList = $FoundAppBloat |
        Select-Object -ExpandProperty Name
}


$DiagnosticResult = [ordered]@{
    "SvcScore"            = $SvcScore
    "TotalServices"       = if ($null -ne $AllServices) {
        @($AllServices).Count
    }
    else {
        0
    }
    "RunningServices"     = if ($null -ne $RunningServices) {
        @($RunningServices).Count
    }
    else {
        0
    }
    "StartupCount"        = if ($null -ne $StartupList) {
        @($StartupList).Count
    }
    else {
        0
    }
    "AutoTasksCount"      = if ($null -ne $AutoTasks) {
        @($AutoTasks).Count
    }
    else {
        0
    }
    "BloatServicesFound"  = $BloatServicesList
    "BloatAppxFound"      = $BloatAppxList
    "BackgroundHogsCount" = if ($null -ne $BackgroundHogs) {
        @($BackgroundHogs).Count
    }
    else {
        0
    }
    "Issues"              = $SvcIssues
    "Warnings"            = $SvcWarnings
}


# Convert the diagnostic result to a compact JSON string.
$JsonOutput = $DiagnosticResult |
    ConvertTo-Json -Depth 3 -Compress

Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"
