# Build and Usage

## Requirements

VRM21 Windows Diagnostic Engine is designed for Windows systems.

The first edition uses:

* Python **3.11.9**
* PowerShell **7.6.5**
* PySide6 **6.10.2**

The diagnostic modules rely primarily on Windows PowerShell/CIM, WMI, performance counters, and Windows diagnostic utilities.

## Python Environment

Create a Python virtual environment using Python 3.11:

```powershell
py -3.11 -m venv venv311
```

Activate it:

```powershell
.\venv311\Scripts\Activate.ps1
```

Install the Python dependencies:

```powershell
python -m pip install -r requirements.txt
```

Verify the Python version:

```powershell
python --version
```

Expected version:

```text
Python 3.11.9
```

## PowerShell Environment

Verify PowerShell:

```powershell
$PSVersionTable.PSVersion
```

The development reference environment uses:

```text
PowerShell 7.6.5
```

## Project Layout

The repository follows the general structure:

```text
VRM21-Windows-Diagnostic-Engine/
│
├── SystemAudit.py
├── AuditGUI.py
├── requirements.txt
│
├── diagnostics/
│   ├── CPU-Detailed-Diagnostic.ps1
│   ├── GPU-Detailed-Diagnostic.ps1
│   ├── Driver-Detailed-Diagnostic.ps1
│   ├── Battery-Detailed-Diagnostic.ps1
│   ├── Storage-Diagnostic.ps1
│   ├── Security-Diagnostic.ps1
│   ├── Registry-Startup-Diagnostic.ps1
│   ├── Cache-RecycleBin-Diagnostic.ps1
│   └── WindowsUpdate-Diagnostic.ps1
│
├── reports/
│
├── json/
│
└── docs/
    ├── architecture.md
    ├── diagnostic_modules.md
    ├── output_format.md
    ├── json_schema.md
    ├── build_and_usage.md
    └── limitations.md
```

The exact diagnostic filenames may evolve as the module set changes. The Python engine discovers modules using the `*-Diagnostic.ps1` pattern.

## CLI Usage

Run the main audit engine:

```powershell
python SystemAudit.py
```

The engine can execute the available diagnostic modules according to its command-line configuration.

### Run a Specific Module

```powershell
python SystemAudit.py --module <module-name>
```

### Merge Reports

```powershell
python SystemAudit.py --merge
```

### Specify a Run Identifier

```powershell
python SystemAudit.py --run-id <run-id>
```

Options can be combined where supported.

For example:

```powershell
python SystemAudit.py --module CPU-Detailed-Diagnostic --run-id test001
```

## GUI Usage

Start the graphical interface with:

```powershell
python AuditGUI.py
```

The GUI:

1. Discovers available diagnostic modules.
2. Displays the modules as selectable options.
3. Allows the user to select one or more modules.
4. Starts the audit process.
5. Displays execution output.
6. Merges the selected module reports after execution.

The GUI does not directly implement diagnostic logic. It invokes the Python audit engine.

## Running a PowerShell Module Directly

Individual diagnostic modules can also be executed manually for development or troubleshooting.

Example:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\diagnostics\CPU-Detailed-Diagnostic.ps1
```

Direct execution is useful when:

* Debugging a module.
* Verifying Windows-specific behavior.
* Inspecting raw console output.
* Testing availability of WMI or performance-counter data.

## Administrative Privileges

Some diagnostics may provide more complete information when executed with administrative privileges.

Examples include:

* Windows Update log generation.
* Certain system-level WMI information.
* Access to protected filesystem locations.
* Security-related system information.

However, administrative privileges should not be assumed to be required for every module.

The diagnostic module itself should report when a capability depends on administrative access.

## Report Locations

The Python engine creates report and JSON directories relative to the application base directory.

Generated files generally follow:

```text
reports/
    Audit_<Module>_<run_id>.txt

json/
    <Module>_<run_id>.json
```

Merged reports follow:

```text
reports/
    SystemAudit_ALL_<run_id>.txt
```

## PyInstaller Build

PyInstaller can be used to package the Python application into a Windows executable.

The build environment should contain PyInstaller in addition to the runtime dependencies.

A basic example is:

```powershell
pyinstaller --onefile AuditGUI.py
```

Because the application depends on external PowerShell diagnostic modules, the final packaged application must also provide access to the diagnostic module directory.

The exact packaging configuration should therefore be adapted to the repository layout and deployment model.

## Development Workflow

A recommended development workflow is:

```text
1. Modify a diagnostic module
        │
        ▼
2. Run the module directly
        │
        ▼
3. Verify console output
        │
        ▼
4. Verify JSON markers
        │
        ▼
5. Run SystemAudit.py
        │
        ▼
6. Verify TXT report
        │
        ▼
7. Verify extracted JSON
        │
        ▼
8. Test through AuditGUI.py
```

## Adding a Diagnostic Module

Create a PowerShell script following:

```text
<Name>-Diagnostic.ps1
```

Place it in the diagnostic module directory.

The Python engine will discover it automatically on the next execution.

The module should emit:

```text
---JSON_START---
{ ... }
---JSON_END---
```

so that the Python engine can extract its structured result.

## Troubleshooting

### Module Not Detected

Check that:

* The file is located in the expected diagnostic directory.
* The filename ends with `-Diagnostic.ps1`.
* The PowerShell file is readable.

### JSON Not Generated

Run the module directly and verify that it outputs:

```text
---JSON_START---
```

and:

```text
---JSON_END---
```

Also verify that the content between the markers is valid JSON.

### GUI Does Not Start

Verify:

```powershell
python --version
```

and:

```powershell
python -c "import PySide6; print(PySide6.__version__)"
```

### PowerShell Diagnostic Fails

Run the affected module directly with:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\diagnostics\<module>.ps1
```

This separates module-specific PowerShell problems from Python orchestration problems.
