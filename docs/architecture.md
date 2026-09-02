# Architecture

## Overview

VRM21 Windows Diagnostic Engine is a modular Windows system auditing framework built around a Python execution engine and PowerShell-based diagnostic modules.

The architecture separates:

* **Execution orchestration** — Python
* **System diagnostics** — PowerShell
* **Graphical interface** — PySide6
* **Human-readable reports** — TXT
* **Machine-readable results** — JSON

This separation allows individual diagnostic modules to be developed and maintained independently while keeping a common execution and reporting mechanism.

## High-Level Architecture

```text
                        VRM21 Windows Diagnostic Engine
                                      │
                    ┌─────────────────┴─────────────────┐
                    │                                   │
              AuditGUI.py                         SystemAudit.py
              PySide6 GUI                         CLI / Engine
                    │                                   │
                    └─────────────────┬─────────────────┘
                                      │
                              Module Discovery
                                      │
                                      ▼
                         *-Diagnostic.ps1 Modules
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
               CPU Diagnostic    GPU Diagnostic    Driver Diagnostic
                    │                 │                 │
                    └─────────────────┼─────────────────┘
                                      │
                                      ▼
                            PowerShell Transcript
                                      │
                         ┌────────────┴────────────┐
                         │                         │
                         ▼                         ▼
                    TXT Report                 JSON Data
                         │                         │
                         │                         ▼
                         │                 JSON Output Directory
                         │
                         ▼
                  Optional Report Merge
                         │
                         ▼
              SystemAudit_ALL_<run_id>.txt
```

## Core Components

### `SystemAudit.py`

`SystemAudit.py` is the primary execution engine.

Its responsibilities include:

* Detecting the PowerShell environment.
* Verifying the Python runtime.
* Discovering available diagnostic modules.
* Executing selected PowerShell modules.
* Capturing PowerShell transcripts.
* Extracting structured JSON between predefined markers.
* Saving JSON results.
* Generating individual TXT reports.
* Merging multiple reports into a single audit report.

The engine does not implement hardware-specific diagnostic logic itself. Diagnostic logic remains inside the PowerShell modules.

### `AuditGUI.py`

`AuditGUI.py` provides an optional graphical interface using PySide6.

The GUI is responsible for:

* Discovering available diagnostic modules.
* Presenting modules as selectable checkboxes.
* Starting audit execution.
* Displaying execution output.
* Forwarding module output to the GUI.
* Coordinating report merging after the selected modules have completed.

The GUI delegates actual diagnostic execution to `SystemAudit.py` rather than duplicating the audit logic.

### PowerShell Diagnostic Modules

Diagnostic modules use the naming convention:

```text
*-Diagnostic.ps1
```

Examples include:

```text
CPU-Detailed-Diagnostic.ps1
GPU-Detailed-Diagnostic.ps1
Driver-Detailed-Diagnostic.ps1
Battery-Detailed-Diagnostic.ps1
Storage-Diagnostic.ps1
Security-Diagnostic.ps1
```

The exact module set is determined dynamically from the contents of the diagnostic module directory.

Each module is responsible for:

1. Collecting system information.
2. Performing its diagnostic checks.
3. Printing human-readable results.
4. Generating structured JSON output.

## Module Discovery

The Python engine automatically searches the diagnostic module directory for files matching:

```text
*-Diagnostic.ps1
```

This avoids maintaining a hard-coded module registry in the Python execution engine.

Adding a compatible diagnostic module therefore primarily requires placing the PowerShell file in the expected module directory.

## Execution Flow

A typical audit follows this sequence:

```text
1. Start CLI or GUI
        │
        ▼
2. Initialize Python environment
        │
        ▼
3. Discover diagnostic modules
        │
        ▼
4. Select module(s)
        │
        ▼
5. Execute PowerShell module
        │
        ▼
6. Capture transcript
        │
        ├───────────────► TXT report
        │
        └───────────────► JSON extraction
                                │
                                ▼
                         JSON result file
        │
        ▼
7. Repeat for additional modules
        │
        ▼
8. Optionally merge TXT reports
```

## PowerShell Execution

The Python engine launches PowerShell with a controlled command-line configuration.

The execution uses:

```text
-NoProfile
-ExecutionPolicy Bypass
```

The diagnostic module is executed inside a transcript session so that its console output can be retained as a report.

The framework therefore separates two forms of output:

* **Transcript output** for human inspection.
* **JSON output** for programmatic processing.

## JSON Extraction

Diagnostic modules emit structured data between fixed markers:

```text
---JSON_START---
{ ... }
---JSON_END---
```

The Python engine searches the transcript for this block, parses the JSON content, and stores it separately.

This design allows PowerShell modules to remain readable when executed manually while still exposing structured data to Python and future analysis tools.

## Report Management

Each execution uses a run identifier:

```text
<run_id>
```

The identifier is incorporated into generated report and JSON filenames.

Typical output files follow this pattern:

```text
Audit_<Module>_<run_id>.txt
<Module>_<run_id>.json
```

When report merging is requested, individual TXT reports are combined into:

```text
SystemAudit_ALL_<run_id>.txt
```

## PyInstaller Compatibility

The GUI contains path handling for both normal Python execution and PyInstaller frozen applications.

The application determines its base directory according to the execution environment and uses that location to locate the engine and diagnostic modules.

This allows the same application layout to support both:

```text
Python source execution
```

and:

```text
PyInstaller-based executable deployment
```

## Design Principles

The first edition follows several architectural principles:

### Modular Diagnostics

Each diagnostic domain is implemented independently.

### Separation of Concerns

Python handles orchestration and report processing while PowerShell handles Windows-specific diagnostics.

### Automatic Discovery

Diagnostic modules are discovered from the filesystem rather than requiring a manually maintained module list.

### Dual Output

Human-readable TXT output and machine-readable JSON output are generated from the same audit execution.

### Read-Only Diagnostics

The diagnostic modules are designed to inspect system state without intentionally modifying configuration or deleting system data.

### Extensibility

The architecture allows additional diagnostic modules to be added without fundamentally changing the execution engine.
