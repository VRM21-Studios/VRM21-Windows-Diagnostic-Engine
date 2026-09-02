# ======================================================================
# Power Policy Diagnostic
# Version : 1.1
# Target  : PowerShell 5.1 Compatible
# Mode    : Read-Only Audit
# ======================================================================

Write-Host "===================================================="
Write-Host " POWER & ENERGY POLICY DIAGNOSTIC"
Write-Host "====================================================`n"

# ----------------------------------------------------------------------
# Helper: Read a powercfg value safely
# ----------------------------------------------------------------------
function Get-PowerCfgValue {
    param (
        [string]$Scheme,
        [string]$SubGroup,
        [string]$Setting
    )

    $out = powercfg /q $Scheme $SubGroup $Setting 2>$null

    foreach ($line in $out) {

        # HEX format (legacy Windows output)
        if ($line -match "Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)") {
            try {
                return [Convert]::ToInt32($Matches[1], 16)
            }
            catch {
                return $null
            }
        }

        # DECIMAL format (newer Windows output)
        if ($line -match "Current AC Power Setting Index:\s+([0-9]+)") {
            try {
                return [int]$Matches[1]
            }
            catch {
                return $null
            }
        }
    }

    return $null
}

# ----------------------------------------------------------------------
# Active Power Plan
# ----------------------------------------------------------------------
$ActivePlanRaw = powercfg /getactivescheme
$ActivePlanGuid = "Unknown"
$ActivePlanName = "Unknown"

if ($ActivePlanRaw -match 'GUID:\s+([a-fA-F0-9\-]+)') {
    $ActivePlanGuid = $Matches[1]
}

if ($ActivePlanRaw -match '\((.+)\)') {
    $ActivePlanName = $Matches[1]
}

Write-Host "Active Power Plan"
Write-Host "-----------------"
Write-Host "GUID : $ActivePlanGuid"
Write-Host "Name : $ActivePlanName`n"

# ----------------------------------------------------------------------
# CPU Power Management
# ----------------------------------------------------------------------
$SUB_PROCESSOR = "54533251-82be-4824-96c1-47b60b740d00"
$MIN_PROC      = "893dee8e-2bef-41e0-89c6-b55d0929964c"
$MAX_PROC      = "bc5038f7-23e0-4960-96da-33abaf5935ec"
$CORE_PARK     = "0cc5b647-c1df-4637-891a-dec35c318583"

$CpuMin = Get-PowerCfgValue $ActivePlanGuid $SUB_PROCESSOR $MIN_PROC
$CpuMax = Get-PowerCfgValue $ActivePlanGuid $SUB_PROCESSOR $MAX_PROC
$CorePark = Get-PowerCfgValue $ActivePlanGuid $SUB_PROCESSOR $CORE_PARK

Write-Host "CPU Power Policy"
Write-Host "----------------"

if ($CpuMin -ne $null) {
    Write-Host ("Min CPU State  : {0}%" -f $CpuMin)
}
else {
    Write-Host "Min CPU State  : Unknown"
}

if ($CpuMax -ne $null) {
    Write-Host ("Max CPU State  : {0}%" -f $CpuMax)
}
else {
    Write-Host "Max CPU State  : Unknown"
}

if ($CorePark -ne $null) {
    if ($CorePark -eq 0) {
        Write-Host "Core Parking   : Disabled"
    }
    else {
        Write-Host "Core Parking   : Enabled"
    }
}
else {
    Write-Host "Core Parking   : Unknown"
}

Write-Host ""

# ----------------------------------------------------------------------
# PCI Express ASPM
# ----------------------------------------------------------------------
$SUB_PCI = "501a4d13-42af-4429-9fd1-a8218c268e20"
$ASPM    = "ee12f906-d277-404b-b6da-e5fa1a576df5"

$PcieAspm = Get-PowerCfgValue $ActivePlanGuid $SUB_PCI $ASPM

Write-Host "PCI Express Power"
Write-Host "-----------------"

if ($PcieAspm -ne $null) {
    switch ($PcieAspm) {
        0 {
            Write-Host "ASPM Mode     : Off (Latency-Friendly)"
        }
        1 {
            Write-Host "ASPM Mode     : Moderate Power Savings"
        }
        2 {
            Write-Host "ASPM Mode     : Maximum Power Savings"
        }
        default {
            Write-Host "ASPM Mode     : Unknown"
        }
    }
}
else {
    Write-Host "ASPM Mode     : Unknown"
}

Write-Host ""

# ----------------------------------------------------------------------
# USB Selective Suspend
# ----------------------------------------------------------------------
$SUB_USB = "2a737441-1930-4402-8d77-b2bebba308a3"
$USB_SUSP = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"

$UsbSuspend = Get-PowerCfgValue $ActivePlanGuid $SUB_USB $USB_SUSP

Write-Host "USB Power Management"
Write-Host "--------------------"

if ($UsbSuspend -ne $null) {
    if ($UsbSuspend -eq 0) {
        Write-Host "USB Selective Suspend : Disabled"
    }
    else {
        Write-Host "USB Selective Suspend : Enabled"
    }
}
else {
    Write-Host "USB Selective Suspend : Unknown"
}

Write-Host ""

# ----------------------------------------------------------------------
# Sleep / Hibernate
# ----------------------------------------------------------------------
Write-Host "Sleep States"
Write-Host "------------"

powercfg /a | ForEach-Object {
    Write-Host $_
}

Write-Host ""

# ----------------------------------------------------------------------
# High-Level Classification
# ----------------------------------------------------------------------
$Profile = "BALANCED_GENERAL"

if ($CpuMin -ne $null -and $CpuMin -eq 100) {
    $Profile = "LATENCY_MAX_PERFORMANCE"
}
elseif (
    $CpuMin -ne $null -and
    $CpuMin -le 5 -and
    $CorePark -ne $null -and
    $CorePark -ne 0
) {
    $Profile = "POWER_SAVING_FOCUSED"
}

Write-Host "===================================================="
Write-Host " POWER POLICY SUMMARY"
Write-Host "===================================================="
Write-Host "Profile Classification : $Profile"
Write-Host ""
Write-Host "Notes:"
Write-Host "- PowerShell 5.1 compatible"
Write-Host "- Read-only (no changes applied)"
Write-Host "- Classification is contextual"
Write-Host ""
Write-Host "===================================================="
Write-Host " POWER & ENERGY POLICY DIAGNOSTIC COMPLETE"
Write-Host "===================================================="

# ======================================================================
# JSON Export for Python / LLM Integration
# ======================================================================

$DiagnosticResult = [ordered]@{
    "ActivePlanName" = $ActivePlanName
    "ActivePlanGuid" = $ActivePlanGuid

    "CpuMinStatePct" = if ($null -ne $CpuMin) {
        $CpuMin
    }
    else {
        $null
    }

    "CpuMaxStatePct" = if ($null -ne $CpuMax) {
        $CpuMax
    }
    else {
        $null
    }

    "CoreParking" = if ($null -ne $CorePark) {
        if ($CorePark -eq 0) {
            "Disabled"
        }
        else {
            "Enabled"
        }
    }
    else {
        "Unknown"
    }

    "PcieAspmMode" = if ($null -ne $PcieAspm) {
        switch ($PcieAspm) {
            0 {
                "Off (Latency-Friendly)"
            }
            1 {
                "Moderate"
            }
            2 {
                "Maximum"
            }
            default {
                "Unknown"
            }
        }
    }
    else {
        "Unknown"
    }

    "UsbSuspend" = if ($null -ne $UsbSuspend) {
        if ($UsbSuspend -eq 0) {
            "Disabled"
        }
        else {
            "Enabled"
        }
    }
    else {
        "Unknown"
    }

    "ProfileClass" = $Profile
}

# Convert the diagnostic result to compact JSON.
$JsonOutput = $DiagnosticResult | ConvertTo-Json -Depth 3 -Compress

Write-Output "---JSON_START---"
Write-Output $JsonOutput
Write-Output "---JSON_END---"
