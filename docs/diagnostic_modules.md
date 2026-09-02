# Diagnostic Modules

## Overview

VRM21 Windows Diagnostic Engine uses independent PowerShell modules to inspect different areas of a Windows system.

Each module follows the common naming convention:

```text
*-Diagnostic.ps1
```

Modules are automatically discovered by the Python engine.

The module architecture allows individual diagnostics to evolve independently while maintaining a consistent execution and output interface.

## Module Categories

### CPU Detailed Diagnostic

**Purpose:** Assess CPU information, processor activity, temperature information, and basic performance conditions.

The module collects:

* Processor model
* Core count
* Thread count
* Maximum reported clock speed
* CPU usage information
* Per-processor usage information
* Top CPU-consuming processes
* Thermal information when available
* A heuristic CPU health score

Structured output includes:

```text
ProcessorName
Cores
Threads
MaxSpeedMHz
AvgUsagePct
TemperatureC
TopProcesses
Status
```

### GPU Detailed Diagnostic

**Purpose:** Collect GPU hardware, display, utilization, thermal, and graphics-process information.

The module examines:

* Graphics adapters
* Adapter memory information
* Integrated/dedicated GPU classification
* GPU engine activity
* Display information
* DirectX-related registry information
* GPU temperature sources when available
* Selected graphics-intensive processes

Structured output includes:

```text
GPUs
HasDedicatedGPU
GraphicsIntensiveProcesses
```

### Driver Detailed Diagnostic

**Purpose:** Analyze installed drivers, device status, driver metadata, driver files, and selected critical driver categories.

The module examines:

* Installed drivers
* Device problem states
* Driver signing information
* Driver age metadata
* Referenced driver files
* Duplicate driver entries
* GPU-related drivers
* Network adapter drivers
* Boot-critical driver metadata

A heuristic driver score is also generated.

Structured output includes:

```text
TotalDrivers
DriverScore
UnsignedDriversCount
OldDriversCount
ProblemDevicesCount
MissingFilesCount
DuplicateDriversCount
Issues
Warnings
```

### Battery Detailed Diagnostic

**Purpose:** Assess battery information, capacity, wear level, cycle count, power draw, and temperature when available.

The module collects:

* Battery status
* Estimated charge
* Estimated runtime
* Battery chemistry
* Design voltage
* Design capacity
* Full-charge capacity
* Estimated wear level
* Cycle count when exposed by the system
* Power draw when available
* Battery temperature when exposed
* Battery health score

Structured output includes:

```text
BatteryScore
Status
Chemistry
WearLevelPct
CycleCount
DischargeRate
Issues
Warnings
```

On systems without a battery, such as many desktop systems, the module exits after reporting that no battery was detected.

### Storage Diagnostic

**Purpose:** Inspect physical and logical storage conditions, disk activity, storage health information, large files, and temporary-file usage.

The module examines:

* Physical disks
* SSD-related information
* Logical drive capacity
* Disk read/write activity
* Physical disk health information
* Large files on the system drive
* Temporary-file usage
* Storage-related recommendations

Structured output includes:

```text
LogicalDrives
ReadSpeedMBps
WriteSpeedMBps
DiskHealthStatus
TotalTempFilesMB
HasSSDOptimization
LowSpaceAlerts
```

### Security Diagnostic

**Purpose:** Perform a read-only security-oriented system audit using Windows security state, process, network, persistence, filesystem, and UAC information.

The module examines:

* Microsoft Defender status
* Real-time protection
* Signature age
* Suspicious process heuristics
* Established network connections
* Flagged network ports
* Registry startup entries
* Recently modified executable files
* Browser-related paths
* UAC configuration
* System uptime
* Recent security event log entries

A heuristic security score is generated.

Structured output includes:

```text
SecurityScore
DefenderEnabled
SuspiciousProcessCount
SuspiciousPortCount
TotalStartupEntries
UacEnabled
Issues
Warnings
```

### Registry Startup Diagnostic

**Purpose:** Inspect Windows Registry startup entries and classify referenced executables.

The module checks selected:

```text
HKLM\...\Run
HKCU\...\Run
HKLM\...\RunOnce
HKCU\...\RunOnce
```

It attempts to extract executable paths and classifies entries as:

```text
UNKNOWN
STALE_ENTRY
SYSTEM_CORE
ACTIVE
USER_OPTIONAL
```

The module also reports entries whose referenced executable paths cannot be found.

### Cache & Recycle Bin Diagnostic

**Purpose:** Analyze temporary data, selected browser cache directories, Prefetch data, and Recycle Bin usage.

The module examines:

* User temporary files
* System temporary files
* Prefetch
* Microsoft Edge cache
* Google Chrome cache
* Recycle Bin
* Total potentially reclaimable space

Structured output includes:

```text
TotalCacheBytes
RecycleBinBytes
TotalWasteBytes
TotalWasteFormatted
Status
PathsScanned
```

The module operates in read-only mode and does not automatically delete detected files.

### Windows Update Diagnostic

**Purpose:** Inspect Windows Update log information and identify entries matching selected diagnostic keywords.

The module:

* Checks administrative execution status.
* Generates a Windows Update log when necessary.
* Scans the resulting log.
* Identifies matching entries for selected keywords.
* Limits displayed matches.
* Exports summary information as JSON.

Structured output includes:

```text
IsAdmin
LogGenerated
TotalLinesScanned
MatchedLinesCount
MaxLinesReached
```

## Common Module Behavior

Although each module has domain-specific logic, diagnostic modules generally follow the same pattern:

```text
Initialize
    │
    ▼
Collect system information
    │
    ▼
Evaluate diagnostic conditions
    │
    ▼
Display human-readable results
    │
    ▼
Generate structured JSON
```

## Read-Only Design

The diagnostic modules are intended to inspect system state.

They do not intentionally:

* Delete user files
* Modify registry configuration
* Disable Windows services
* Change security settings
* Install drivers
* Modify hardware configuration

Some modules may invoke Windows utilities that generate diagnostic data, such as the Windows battery report or Windows Update log. These operations are intended to collect information rather than alter system configuration.

## Extending the Module Set

A new diagnostic module should:

1. Be implemented as a PowerShell script.
2. Follow the `*-Diagnostic.ps1` naming convention.
3. Produce human-readable console output.
4. Emit structured JSON.
5. Use the standard JSON markers:

```text
---JSON_START---
...
---JSON_END---
```

6. Avoid modifying system configuration unless the architecture is explicitly expanded beyond read-only auditing.

The Python engine can then discover the module automatically.
