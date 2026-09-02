# Output Format

## Overview

VRM21 Windows Diagnostic Engine produces two primary output formats:

1. **TXT reports** for human-readable audit results.
2. **JSON files** for structured processing and future automation.

The same diagnostic execution can therefore be inspected manually or consumed programmatically.

## TXT Output

TXT output is based on the PowerShell transcript generated during module execution.

A typical diagnostic module produces output organized into numbered sections:

```text
[1] BASIC INFORMATION
[2] PERFORMANCE
[3] HEALTH
[4] RECOMMENDATIONS
...
```

The exact sections depend on the diagnostic module.

The transcript preserves diagnostic messages, warnings, measurements, and recommendations produced during execution.

## Individual Reports

Individual module reports follow the general naming convention:

```text
Audit_<Module>_<run_id>.txt
```

where:

* `<Module>` identifies the diagnostic module.
* `<run_id>` identifies the execution instance.

Example:

```text
Audit_CPU-Detailed-Diagnostic_20260902_210000.txt
```

The exact run identifier format is determined by the Python execution engine.

## Merged Report

When report merging is requested, individual reports are combined into:

```text
SystemAudit_ALL_<run_id>.txt
```

The merged report contains the output of multiple diagnostic modules in a single text file.

Temporary individual reports used for the merge are removed by the current merge implementation after successful report collection.

## JSON Output

Each diagnostic module emits a JSON object between two fixed markers:

```text
---JSON_START---
{ ... }
---JSON_END---
```

These markers provide a stable boundary between human-readable diagnostic output and machine-readable data.

The Python engine extracts the JSON block and saves it separately.

## JSON File Naming

Extracted JSON files generally follow:

```text
<Module>_<run_id>.json
```

Example:

```text
CPU-Detailed-Diagnostic_20260902_210000.json
```

## JSON Design

JSON output is intended to contain the most useful structured diagnostic information from a module.

Typical fields include:

* Numeric measurements
* Status values
* Boolean states
* Counts
* Lists of detected conditions
* Warnings
* Issues
* Module-specific diagnostic data

The JSON schema is module-specific rather than a single flat universal schema.

The complete field reference is documented in:

```text
docs/json_schema.md
```

## Human-Readable vs Structured Output

The two output forms serve different purposes.

| Format | Primary Use                                 |
| ------ | ------------------------------------------- |
| TXT    | Manual inspection and audit reports         |
| JSON   | Programmatic processing and future analysis |

TXT output may contain explanatory text that is not represented directly in JSON.

Conversely, JSON may preserve structured values that are inconvenient to read in a plain-text report.

## JSON Extraction Contract

Diagnostic modules should keep the JSON markers unchanged:

```text
---JSON_START---
---JSON_END---
```

The Python engine uses these markers to identify structured output.

Changing the markers without updating the Python engine can prevent JSON extraction.

## Error and Availability Conditions

Not every Windows system exposes every diagnostic capability.

For example:

* Battery information may not exist on desktop systems.
* Battery cycle count may not be exposed by firmware.
* Temperature sensors may not be available.
* Certain performance counters may be unavailable.
* Hardware-specific WMI providers may return incomplete information.

A missing diagnostic value should therefore be interpreted as **unavailable information**, not automatically as a fault.

The exact behavior for each module is described in `diagnostic_modules.md` and the known technical limitations are documented in `limitations.md`.

## Output Directories

The Python engine maintains separate locations for:

```text
Reports
JSON results
```

The actual paths are derived from the repository/application base directory rather than requiring hard-coded absolute paths.

This is important for both normal Python execution and packaged application deployment.
