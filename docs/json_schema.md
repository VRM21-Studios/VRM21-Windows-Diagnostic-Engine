# JSON Schema

## Overview

VRM21 Windows Diagnostic Engine uses JSON as its machine-readable diagnostic output format.

Each PowerShell diagnostic module emits one JSON object between:

```text
---JSON_START---
...
---JSON_END---
```

The Python engine extracts this object from the PowerShell transcript and saves it as a `.json` file.

The first edition uses **module-specific JSON schemas** rather than forcing every diagnostic module into a single universal structure.

## Common Structure

Modules generally expose some combination of:

```json
{
  "Score": 0,
  "Status": null,
  "Issues": [],
  "Warnings": []
}
```

Not every module contains all of these fields.

Fields are defined according to the information relevant to each diagnostic domain.

## CPU Diagnostic

```json
{
  "ProcessorName": "string",
  "Cores": "integer",
  "Threads": "integer",
  "MaxSpeedMHz": "integer",
  "AvgUsagePct": "number|null",
  "TemperatureC": "number|null",
  "TopProcesses": [],
  "Status": "string"
}
```

### Fields

| Field           | Type        | Description                            |
| --------------- | ----------- | -------------------------------------- |
| `ProcessorName` | string      | Reported processor name                |
| `Cores`         | integer     | Reported CPU core count                |
| `Threads`       | integer     | Reported logical processor count       |
| `MaxSpeedMHz`   | integer     | Reported maximum CPU speed             |
| `AvgUsagePct`   | number/null | CPU usage value produced by the module |
| `TemperatureC`  | number/null | Temperature information when available |
| `TopProcesses`  | array       | Selected high-CPU processes            |
| `Status`        | string      | Diagnostic status                      |

## GPU Diagnostic

```json
{
  "GPUs": [],
  "HasDedicatedGPU": "boolean",
  "GraphicsIntensiveProcesses": []
}
```

### Fields

| Field                        | Type    | Description                                                   |
| ---------------------------- | ------- | ------------------------------------------------------------- |
| `GPUs`                       | array   | Detected graphics adapter information                         |
| `HasDedicatedGPU`            | boolean | Module classification of dedicated GPU availability           |
| `GraphicsIntensiveProcesses` | array   | Processes selected by the module's graphics-process heuristic |

## Driver Diagnostic

```json
{
  "TotalDrivers": "integer",
  "DriverScore": "number",
  "UnsignedDriversCount": "integer",
  "OldDriversCount": "integer",
  "ProblemDevicesCount": "integer",
  "MissingFilesCount": "integer",
  "DuplicateDriversCount": "integer",
  "Issues": [],
  "Warnings": []
}
```

### Fields

| Field                   | Type    | Description                               |
| ----------------------- | ------- | ----------------------------------------- |
| `TotalDrivers`          | integer | Number of detected driver entries         |
| `DriverScore`           | number  | Heuristic driver audit score              |
| `UnsignedDriversCount`  | integer | Count of unsigned driver entries detected |
| `OldDriversCount`       | integer | Count classified as old by the module     |
| `ProblemDevicesCount`   | integer | Devices reported with problem states      |
| `MissingFilesCount`     | integer | Referenced driver files not found         |
| `DuplicateDriversCount` | integer | Driver entries grouped as duplicates      |
| `Issues`                | array   | Detected issues                           |
| `Warnings`              | array   | Detected warnings                         |

## Battery Diagnostic

```json
{
  "BatteryScore": "number",
  "Status": "number",
  "Chemistry": "string",
  "WearLevelPct": "number|null",
  "CycleCount": "number|null",
  "DischargeRate": "number|null",
  "Issues": [],
  "Warnings": []
}
```

### Fields

| Field           | Type        | Description                        |
| --------------- | ----------- | ---------------------------------- |
| `BatteryScore`  | number      | Heuristic battery health score     |
| `Status`        | number      | Windows battery status code        |
| `Chemistry`     | string      | Reported battery chemistry         |
| `WearLevelPct`  | number/null | Estimated capacity wear percentage |
| `CycleCount`    | number/null | Battery cycle count when available |
| `DischargeRate` | number/null | Reported power draw value          |
| `Issues`        | array       | Critical battery conditions        |
| `Warnings`      | array       | Battery warnings                   |

## Storage Diagnostic

```json
{
  "LogicalDrives": [],
  "ReadSpeedMBps": "number",
  "WriteSpeedMBps": "number",
  "DiskHealthStatus": [],
  "TotalTempFilesMB": "number",
  "HasSSDOptimization": "boolean",
  "LowSpaceAlerts": []
}
```

### Fields

| Field                | Type    | Description                                |
| -------------------- | ------- | ------------------------------------------ |
| `LogicalDrives`      | array   | Logical drive information                  |
| `ReadSpeedMBps`      | number  | Disk read activity measurement             |
| `WriteSpeedMBps`     | number  | Disk write activity measurement            |
| `DiskHealthStatus`   | array   | Physical disk health information           |
| `TotalTempFilesMB`   | number  | Estimated temporary-file size              |
| `HasSSDOptimization` | boolean | Module-specific SSD-related classification |
| `LowSpaceAlerts`     | array   | Logical drives with low-space conditions   |

## Security Diagnostic

```json
{
  "SecurityScore": "number",
  "DefenderEnabled": "boolean",
  "SuspiciousProcessCount": "integer",
  "SuspiciousPortCount": "integer",
  "TotalStartupEntries": "integer",
  "UacEnabled": "boolean",
  "Issues": [],
  "Warnings": []
}
```

### Fields

| Field                    | Type    | Description                                                  |
| ------------------------ | ------- | ------------------------------------------------------------ |
| `SecurityScore`          | number  | Heuristic security audit score                               |
| `DefenderEnabled`        | boolean | Defender state reported by the module                        |
| `SuspiciousProcessCount` | integer | Processes matching the module's suspicious-process heuristic |
| `SuspiciousPortCount`    | integer | Connections/ports matching the module's flagged-port checks  |
| `TotalStartupEntries`    | integer | Startup entries detected by the module                       |
| `UacEnabled`             | boolean | UAC state                                                    |
| `Issues`                 | array   | Detected security issues                                     |
| `Warnings`               | array   | Security warnings                                            |

## Registry Startup Diagnostic

The Registry Startup module exports:

```json
{
  "TotalEntries": "integer",
  "Summary": [],
  "StaleEntries": [],
  "UserOptional": []
}
```

### Fields

| Field          | Type    | Description                                       |
| -------------- | ------- | ------------------------------------------------- |
| `TotalEntries` | integer | Number of inspected startup entries               |
| `Summary`      | array   | Classification results                            |
| `StaleEntries` | array   | Entries referencing missing executable paths      |
| `UserOptional` | array   | Entries classified as user-optional by the module |

## Cache & Recycle Bin Diagnostic

```json
{
  "TotalCacheBytes": "number",
  "RecycleBinBytes": "number",
  "TotalWasteBytes": "number",
  "TotalWasteFormatted": "string",
  "Status": "string",
  "PathsScanned": []
}
```

### Fields

| Field                 | Type   | Description                                        |
| --------------------- | ------ | -------------------------------------------------- |
| `TotalCacheBytes`     | number | Total measured cache size                          |
| `RecycleBinBytes`     | number | Recycle Bin size                                   |
| `TotalWasteBytes`     | number | Combined measured temporary/cache/recycle-bin size |
| `TotalWasteFormatted` | string | Human-readable size representation                 |
| `Status`              | string | Module status                                      |
| `PathsScanned`        | array  | Paths inspected during the diagnostic              |

## Windows Update Diagnostic

```json
{
  "IsAdmin": "boolean",
  "LogGenerated": "boolean",
  "TotalLinesScanned": "integer",
  "MatchedLinesCount": "integer",
  "MaxLinesReached": "boolean"
}
```

### Fields

| Field               | Type    | Description                                                   |
| ------------------- | ------- | ------------------------------------------------------------- |
| `IsAdmin`           | boolean | Indicates administrative execution state                      |
| `LogGenerated`      | boolean | Indicates whether the module generated the Windows Update log |
| `TotalLinesScanned` | integer | Number of log lines scanned                                   |
| `MatchedLinesCount` | integer | Number of matching log lines                                  |
| `MaxLinesReached`   | boolean | Indicates that the configured display limit was reached       |

## Schema Stability

The JSON marker format is part of the Python-to-PowerShell interface:

```text
---JSON_START---
---JSON_END---
```

Module field names should remain stable once consumers begin depending on them.

Any deliberate schema change should therefore be treated as an interface change rather than a cosmetic modification.

## Future Schema Evolution

The current schema is intentionally lightweight.

Future versions may introduce:

* Common metadata fields
* Module version
* Audit timestamp
* Host information
* Execution status
* Diagnostic capability status
* Explicit unavailable/null semantics
* Schema version
* More detailed nested measurements
* Cross-module aggregation

Such changes should preserve backward compatibility where practical.
