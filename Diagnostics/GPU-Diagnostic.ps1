# ======================================================================
# GPU Detailed Diagnostic Tool
# ======================================================================

Write-Host "=== GPU DETAILED DIAGNOSTIC ===" -ForegroundColor Cyan

# ======================================================================
# 1. GPU HARDWARE INFORMATION
# ======================================================================
Write-Host "`n[1] GPU HARDWARE INFORMATION" -ForegroundColor Yellow

$GPUs = Get-CimInstance Win32_VideoController | Where-Object {
    $_.Name -notlike "*Remote*" -and $_.Name -notlike "*Microsoft*"
}

if (-not $GPUs) {
    Write-Host "No supported GPUs detected" -ForegroundColor Yellow
} else {
    foreach ($GPU in $GPUs) {
        Write-Host "`nGPU: $($GPU.Name)" -ForegroundColor White
        Write-Host "  Adapter RAM    : $([math]::Round($GPU.AdapterRAM / 1GB, 2)) GB"
        Write-Host "  Driver Version : $($GPU.DriverVersion)"
        Write-Host "  Driver Date    : $($GPU.DriverDate)"
        Write-Host "  Video Processor: $($GPU.VideoProcessor)"

        # Current display information.
        if ($GPU.CurrentHorizontalResolution -and $GPU.CurrentVerticalResolution) {
            Write-Host "  Resolution     : $($GPU.CurrentHorizontalResolution)x$($GPU.CurrentVerticalResolution)"
            Write-Host "  Refresh Rate   : $($GPU.CurrentRefreshRate) Hz"
            Write-Host "  Bits/Pixel     : $($GPU.CurrentBitsPerPixel)"
        }

        # Basic integrated/dedicated classification.
        if ($GPU.Name -match "Intel|HD Graphics|UHD Graphics") {
            Write-Host "  Type           : Integrated Graphics" -ForegroundColor Blue
        } else {
            Write-Host "  Type           : Dedicated Graphics" -ForegroundColor Green
        }
    }
}

# ======================================================================
# 2. GPU PERFORMANCE COUNTERS
# ======================================================================
Write-Host "`n[2] GPU PERFORMANCE COUNTERS" -ForegroundColor Yellow

try {
    # GPU engine utilization.
    $GPUUsage = Get-Counter "\GPU Engine(*)\Utilization Percentage" -ErrorAction SilentlyContinue

    if ($GPUUsage) {
        $ActiveGPUs = $GPUUsage.CounterSamples |
            Where-Object { $_.CookedValue -gt 0 } |
            Group-Object { $_.InstanceName.Split('_')[0] }

        if ($ActiveGPUs) {
            Write-Host "Active GPU Engines:" -ForegroundColor White

            foreach ($GPU in $ActiveGPUs) {
                $MaxUsage = ($GPU.Group | Measure-Object -Property CookedValue -Maximum).Maximum

                Write-Host "  $($GPU.Name): $([math]::Round($MaxUsage, 1))% usage" -ForegroundColor $(
                    if ($MaxUsage -gt 80) { "Red" }
                    elseif ($MaxUsage -gt 50) { "Yellow" }
                    else { "Green" }
                )
            }
        } else {
            Write-Host "No active GPU usage detected" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "GPU performance counters unavailable" -ForegroundColor Gray
}

# ======================================================================
# 3. GRAPHICS-INTENSIVE PROCESSES
# ======================================================================
Write-Host "`n[3] GRAPHICS-INTENSIVE PROCESSES" -ForegroundColor Yellow

$GraphicsProcesses = Get-Process | Where-Object {
    $_.ProcessName -match "chrome|firefox|edge|opera|photoshop|premiere|afterfx|illustrator|indesign|davinci|blender|maya|3ds|unity|unreal|steam|epic|battle.net|origin|riot|valorant|csgo|dota|lol|overwatch|fortnite|minecraft|javaw|python|matlab"
} |
    Sort-Object WorkingSet -Descending |
    Select-Object -First 15

if ($GraphicsProcesses) {
    Write-Host "Potential graphics-intensive processes:" -ForegroundColor White

    $GraphicsProcesses |
        Format-Table ProcessName, Id,
            @{Name="Memory(MB)"; Expression={[math]::Round($_.WorkingSet / 1MB, 2)}},
            CPU -AutoSize
} else {
    Write-Host "No graphics-intensive processes detected" -ForegroundColor Green
}

# ======================================================================
# 4. DISPLAY CONFIGURATION
# ======================================================================
Write-Host "`n[4] DISPLAY CONFIGURATION" -ForegroundColor Yellow

$Displays = Get-CimInstance Win32_DesktopMonitor

if ($Displays) {
    foreach ($Display in $Displays) {
        Write-Host "Display: $($Display.Name)" -ForegroundColor White

        if ($Display.ScreenWidth -and $Display.ScreenHeight) {
            Write-Host "  Native Resolution: $($Display.ScreenWidth)x$($Display.ScreenHeight)"
        }

        Write-Host "  PNP Device ID: $($Display.PNPDeviceID)"
    }
} else {
    Write-Host "No display information available" -ForegroundColor Gray
}

# ======================================================================
# 5. DIRECTX INFORMATION
# ======================================================================
Write-Host "`n[5] DIRECTX INFORMATION" -ForegroundColor Yellow

try {
    $DXDiag = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\DirectX" -ErrorAction SilentlyContinue

    if ($DXDiag) {
        Write-Host "DirectX installation information detected" -ForegroundColor Green
    }

    # Check for DirectX-related registry information.
    $FeatureLevels = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\DirectX\*" -ErrorAction SilentlyContinue

    if ($FeatureLevels) {
        Write-Host "DirectX-related feature information detected" -ForegroundColor Green
    }
} catch {
    Write-Host "DirectX information is limited" -ForegroundColor Gray
}

# ======================================================================
# 6. GPU TEMPERATURE AND HEALTH
# ======================================================================
Write-Host "`n[6] GPU TEMPERATURE & HEALTH" -ForegroundColor Yellow

try {
    # Attempt to retrieve GPU temperature information from common WMI namespaces.
    $TempSources = @(
        "\\.\ROOT\CIMV2",
        "\\.\ROOT\WMI",
        "\\.\ROOT\CIMV2\power\thermal"
    )

    $TempFound = $false

    foreach ($Namespace in $TempSources) {
        try {
            $Temperatures = Get-CimInstance `
                -Namespace $Namespace `
                -ClassName *temperature* `
                -ErrorAction SilentlyContinue

            if ($Temperatures) {
                foreach ($Temp in $Temperatures) {
                    if ($Temp.Name -match "GPU" -or $Temp.Description -match "GPU") {

                        $CurrentTemp =
                            if ($Temp.CurrentTemperature) {
                                $Temp.CurrentTemperature
                            }
                            elseif ($Temp.Temperature) {
                                $Temp.Temperature
                            }
                            else {
                                $null
                            }

                        if ($CurrentTemp) {
                            # Preserve the original temperature handling.
                            $TempC = if ($CurrentTemp -gt 100) {
                                $CurrentTemp
                            } else {
                                $CurrentTemp
                            }

                            Write-Host "GPU Temperature: $([math]::Round($TempC, 1))°C" -ForegroundColor $(
                                if ($TempC -gt 85) { "Red" }
                                elseif ($TempC -gt 75) { "Yellow" }
                                else { "Green" }
                            )

                            $TempFound = $true
                            break
                        }
                    }
                }
            }

            if ($TempFound) {
                break
            }
        } catch {
            # Continue with the next namespace.
        }
    }

    if (-not $TempFound) {
        Write-Host "GPU temperature data not available" -ForegroundColor Gray
        Write-Host "  Use manufacturer tools (NVIDIA/AMD/Intel) for detailed monitoring" -ForegroundColor White
    }
} catch {
    Write-Host "Temperature monitoring unavailable" -ForegroundColor Gray
}

# ======================================================================
# 7. GPU PERFORMANCE RECOMMENDATIONS
# ======================================================================
Write-Host "`n[7] GPU PERFORMANCE RECOMMENDATIONS" -ForegroundColor Yellow

$DedicatedGPUs = $GPUs | Where-Object {
    $_.Name -notmatch "Intel|HD Graphics|UHD Graphics"
}

$IntegratedGPUs = $GPUs | Where-Object {
    $_.Name -match "Intel|HD Graphics|UHD Graphics"
}

if ($DedicatedGPUs) {
    Write-Host "Dedicated GPU detected" -ForegroundColor Green
    Write-Host "  - Ensure drivers are up to date" -ForegroundColor White
    Write-Host "  - Use NVIDIA Control Panel/AMD Software for optimization" -ForegroundColor White
}

if ($IntegratedGPUs -and $DedicatedGPUs) {
    Write-Host "Hybrid graphics system detected" -ForegroundColor Cyan
    Write-Host "  - Use graphics settings to assign applications to the dedicated GPU" -ForegroundColor White
    Write-Host "  - Check power settings for GPU switching" -ForegroundColor White
}

if ($IntegratedGPUs -and -not $DedicatedGPUs) {
    Write-Host "Integrated graphics only" -ForegroundColor Blue
    Write-Host "  - Optimize for power efficiency" -ForegroundColor White
    Write-Host "  - Close unnecessary background applications during gaming" -ForegroundColor White
}

# VRAM usage check.
foreach ($GPU in $GPUs) {
    if ($GPU.AdapterRAM -lt 2GB) {
        Write-Host "  Low VRAM: $([math]::Round($GPU.AdapterRAM / 1GB, 1)) GB" -ForegroundColor Yellow
        Write-Host "  - Consider lowering texture quality in graphics-intensive applications" -ForegroundColor White
    }
}

Write-Host "`n=== GPU DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan

# ======================================================================
# 8. JSON EXPORT FOR PYTHON / LLM INTEGRATION
# ======================================================================
$GPUList = @()

if ($GPUs) {
    foreach ($G in $GPUs) {
        $GPUList += [ordered]@{
            "Name"        = $G.Name
            "VRAM_GB"     = [math]::Round($G.AdapterRAM / 1GB, 2)
            "IsDedicated" = if ($G.Name -match "Intel|HD Graphics|UHD Graphics|Radeon Graphics") {
                $false
            } else {
                $true
            }
        }
    }
}

$GraphicsProcs = @()

if ($GraphicsProcesses) {
    # Limit the JSON output to the top five processes.
    $TopProcs = $GraphicsProcesses | Select-Object -First 5

    foreach ($P in $TopProcs) {
        $GraphicsProcs += [ordered]@{
            "Process"  = $P.ProcessName
            "MemoryMB" = [math]::Round($P.WorkingSet / 1MB, 2)
        }
    }
}

$DiagnosticResult = [ordered]@{
    "GPUs"                       = $GPUList
    "HasDedicatedGPU"            = if ($DedicatedGPUs) { $true } else { $false }
    "GraphicsIntensiveProcesses" = $GraphicsProcs
}

# Convert to JSON and output it as a pure string.
$JsonOutput = $DiagnosticResult | ConvertTo-Json -Depth 3 -Compress

Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"
