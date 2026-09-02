# VRM21 Windows Diagnostic Engine

A modular Windows system diagnostic and audit framework built with Python and PowerShell.

VRM21 Windows Diagnostic Engine provides a unified execution layer for collecting system information and diagnostic indicators across multiple Windows subsystems. Diagnostic logic is implemented as independent PowerShell modules, while Python handles module discovery, execution, report generation, JSON extraction, and optional graphical interaction.

---

## Motivation

This project was originally created as a practical diagnostic tool for evaluating a Windows laptop or PC before performing system tuning or optimization.

Before tuning a system, it is useful to understand its current condition: CPU and GPU utilization, storage health and capacity, battery condition, installed drivers, startup entries, background services, temporary files, Windows Update state, and other system-level factors. Without this baseline information, tuning can easily become a trial-and-error process.

The goal of the Windows Diagnostic Engine is therefore to provide a structured baseline of the system before and after tuning. Its modular architecture allows individual diagnostic areas to be inspected independently while also supporting batch execution and consolidated reports.

The project is intentionally designed as a **diagnostic and auditing framework rather than an automatic optimizer**. It collects information, identifies potential areas of concern, and provides recommendations while leaving actual system modifications under the user's control.

---

## Features

* Modular PowerShell-based diagnostic architecture
* Automatic diagnostic module discovery
* Python-based CLI execution engine
* Optional PySide6 graphical interface
* Human-readable TXT reports
* Structured JSON output for programmatic processing
* Batch execution of multiple diagnostic modules
* Merged system audit reports
* Read-only diagnostic approach
* PyInstaller-oriented application path handling
* Designed for future automated and LLM-assisted analysis

---

## Architecture

The project separates orchestration from system-level diagnostics:

```text
                    VRM21 Windows Diagnostic Engine
                                  │
                 ┌────────────────┴────────────────┐
                 │                                 │
           AuditGUI.py                       SystemAudit.py
           PySide6 GUI                       Python Engine
                 │                                 │
                 └────────────────┬────────────────┘
                                  │
                         Diagnostic Discovery
                                  │
                                  ▼
                       PowerShell Diagnostic Modules
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             ▼             ▼
                   CPU           GPU         Storage
                    │             │             │
                    └─────────────┼─────────────┘
                                  │
                                  ▼
                         TXT + JSON Output
```

Python provides the common execution and reporting infrastructure, while each PowerShell module focuses on a specific diagnostic domain.

---

## Diagnostic Modules

The first edition includes diagnostics covering:

* CPU
* GPU
* Drivers
* Battery
* Storage
* Security
* Registry startup entries
* Cache and Recycle Bin
* Windows Update

The module set is discovered dynamically from PowerShell files following the:

```text
*-Diagnostic.ps1
```

naming convention.

See [`docs/diagnostic_modules.md`](docs/diagnostic_modules.md) for the module-level documentation.

---

## Output

Each diagnostic module produces human-readable console output and structured JSON data.

JSON output is delimited by:

```text
---JSON_START---
{ ... }
---JSON_END---
```

The Python engine extracts the structured data and stores it separately from the TXT transcript.

Typical output:

```text
reports/
├── Audit_<Module>_<run_id>.txt
└── SystemAudit_ALL_<run_id>.txt

json/
└── <Module>_<run_id>.json
```

The JSON interface is intended to support future automated processing and cross-module analysis.

See [`docs/output_format.md`](docs/output_format.md) and [`docs/json_schema.md`](docs/json_schema.md).

---

## Requirements

Reference development environment:

* Windows
* Python 3.11.9
* PowerShell 7.6.5
* PySide6 6.10.2

Python dependencies are listed in:

```text
requirements.txt
```

---

## Quick Start

Create a virtual environment:

```powershell
py -3.11 -m venv venv311
```

Activate it:

```powershell
.\venv311\Scripts\Activate.ps1
```

Install dependencies:

```powershell
python -m pip install -r requirements.txt
```

Run the command-line engine:

```powershell
python SystemAudit.py
```

To launch the graphical interface:

```powershell
python AuditGUI.py
```

Individual PowerShell modules can also be executed directly for development and troubleshooting.

See [`docs/build_and_usage.md`](docs/build_and_usage.md) for detailed usage and packaging information.

## Read-Only Design

The diagnostic modules are intended to inspect system state without intentionally modifying system configuration or deleting user data.

The framework should therefore be regarded as a diagnostic and auditing tool rather than a system optimizer or automated repair utility.

Recommendations generated by individual modules are informational and should be evaluated before applying system changes manually.

---

## JSON and Automation

Structured JSON output is a central part of the architecture.

The current implementation provides module-specific schemas containing measurements, classifications, scores, warnings, and other diagnostic information where applicable.

This provides a foundation for future features such as:

* Cross-module analysis
* Historical comparison
* Automated report summarization
* Structured dashboards
* LLM-assisted diagnostic interpretation

These capabilities are not assumed to be implemented in the current edition unless explicitly provided by the source code.

---

## Documentation

| Document                                              | Description                                  |
| ----------------------------------------------------- | -------------------------------------------- |
| [`architecture.md`](docs/architecture.md)             | System architecture and execution flow       |
| [`diagnostic_modules.md`](docs/diagnostic_modules.md) | Diagnostic module overview                   |
| [`output_format.md`](docs/output_format.md)           | TXT and JSON output behavior                 |
| [`json_schema.md`](docs/json_schema.md)               | Module-specific JSON fields                  |
| [`build_and_usage.md`](docs/build_and_usage.md)       | Environment setup, usage, and packaging      |
| [`limitations.md`](docs/limitations.md)               | Technical limitations and diagnostic caveats |

---

## Scope

VRM21 Windows Diagnostic Engine is intended for:

* Windows system inspection
* Hardware and software diagnostics
* Performance observation
* Configuration auditing
* Diagnostic report generation
* Development and experimentation with modular system-audit tooling

It is **not** intended to replace:

* Professional hardware diagnostics
* Standardized performance benchmarks
* Antivirus or endpoint security products
* Malware analysis tools
* Digital forensics platforms
* Vendor-specific hardware monitoring utilities

---

## License

MIT License
Provided as-is, without warranty.

---

## Project Status

This repository represents the first edition of the VRM21 Windows Diagnostic Engine.

The current implementation focuses on establishing a modular diagnostic architecture, consistent report generation, and structured JSON output. Further development may expand diagnostic coverage, improve hardware-specific data collection, and introduce more advanced analysis capabilities.
