import argparse
import subprocess
import datetime
import os
import sys
import shutil
import json
import re
from pathlib import Path


# ==========================================================
# SCRIPT SETUP
# ==========================================================
if not shutil.which("powershell"):
    raise RuntimeError("PowerShell not found in PATH")

MIN_PYTHON = (3, 8)

if sys.version_info < MIN_PYTHON:
    raise RuntimeError(
        f"Python {MIN_PYTHON[0]}.{MIN_PYTHON[1]}+ required, "
        f"found {sys.version_info.major}.{sys.version_info.minor}"
    )

BASE_DIR = Path(__file__).resolve().parent
PS_DIR = BASE_DIR / "Diagnostics"
REPORT_DIR = BASE_DIR / "Reports"
JSON_DIR = BASE_DIR / "JSON_Data"

if not PS_DIR.exists():
    raise RuntimeError(f"Diagnostics directory not found: {PS_DIR}")


# ==========================================================
# MODULE MAP (AUTO DISCOVERY)
# ==========================================================
MODULE_MAP = {}

for ps in PS_DIR.glob("*-Diagnostic.ps1"):
    name = ps.stem.replace("-Diagnostic", "").lower()
    MODULE_MAP[name] = ps.name


# ==========================================================
# POWERSHELL EXECUTOR
# ==========================================================
def run_powershell(ps_script: Path, transcript: Path):
    cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command",
        (
            f"Start-Transcript -Path '{transcript}' -Force; "
            f"& '{ps_script}'; "
            f"Stop-Transcript"
        )
    ]
    subprocess.run(cmd, check=False)


# ==========================================================
# JSON EXTRACTOR
# ==========================================================
def extract_and_clean_json(transcript_path: Path, module: str, run_id: str):
    if not transcript_path.exists():
        return

    content = transcript_path.read_text(
        encoding="utf-8",
        errors="ignore"
    )

    # Extract the JSON block enclosed by the diagnostic markers.
    json_pattern = re.compile(
        r"---JSON_START---\s*(.*?)\s*---JSON_END---",
        re.DOTALL
    )
    match = json_pattern.search(content)

    if match:
        json_str = match.group(1)

        try:
            parsed_json = json.loads(json_str)

            # Store structured diagnostic data separately from the text report.
            JSON_DIR.mkdir(parents=True, exist_ok=True)
            json_file = JSON_DIR / f"{module}_{run_id}.json"

            with open(json_file, "w", encoding="utf-8") as f:
                json.dump(parsed_json, f, indent=4)

            # Remove the JSON block from the transcript so the GUI text viewer
            # remains readable.
            clean_content = json_pattern.sub("", content)
            transcript_path.write_text(
                clean_content,
                encoding="utf-8"
            )

        except json.JSONDecodeError:
            print(f"  ⚠ Failed to parse JSON for {module}")


# ==========================================================
# SINGLE MODULE RUNNER
# ==========================================================
def run_module(module: str, run_id: str):
    if module not in MODULE_MAP:
        print(f"❌ Unknown module: {module}")
        return

    ps_script = PS_DIR / MODULE_MAP[module]

    if not ps_script.exists():
        print(f"❌ Diagnostic script not found: {ps_script}")
        return

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    transcript = REPORT_DIR / f"Audit_{module}_{run_id}.txt"

    print(f"▶ Running {module}")
    run_powershell(ps_script, transcript)

    # Extract structured JSON data after PowerShell execution completes.
    extract_and_clean_json(transcript, module, run_id)

    print(f"✔ Saved report: {transcript}")


# ==========================================================
# REPORT MERGER
# ==========================================================
def merge_reports(run_id: str):
    final_report = REPORT_DIR / f"SystemAudit_ALL_{run_id}.txt"
    files = sorted(REPORT_DIR.glob(f"Audit_*_{run_id}.txt"))

    if not files:
        print("⚠ No reports to merge.")
        return

    with final_report.open("w", encoding="utf-8") as fout:
        fout.write("=" * 80 + "\n")
        fout.write("WINDOWS COMPREHENSIVE SYSTEM AUDIT REPORT\n")
        fout.write("=" * 80 + "\n")
        fout.write(f"Run ID    : {run_id}\n")
        fout.write(f"Generated : {datetime.datetime.now()}\n\n")

        for f in files:
            fout.write("\n" + "#" * 80 + "\n")
            fout.write(f"# MODULE: {f.stem.replace(f'_'+run_id, '')}\n")
            fout.write("#" * 80 + "\n\n")

            with f.open(
                "r",
                encoding="utf-8",
                errors="ignore"
            ) as fin:
                fout.write(fin.read())

    # Remove individual module reports after they have been merged.
    for f in files:
        f.unlink()

    print(f"\n📄 Final text report: {final_report}")
    print(f"📊 Structured JSON data saved to: {JSON_DIR}")
    print("🧹 Temporary reports removed.")


# ==========================================================
# MAIN
# ==========================================================
def main():
    parser = argparse.ArgumentParser(
        description="Windows System Audit Engine"
    )
    parser.add_argument(
        "--module",
        default="all",
        help="Diagnostic module name or 'all'"
    )
    parser.add_argument(
        "--merge",
        action="store_true",
        help="Merge reports after execution"
    )
    parser.add_argument(
        "--run-id",
        help="Shared run identifier for GUI batch execution"
    )

    args = parser.parse_args()

    # ------------------------------------------------------
    # Shared Run ID
    # ------------------------------------------------------
    if args.run_id:
        run_id = args.run_id
    else:
        run_id = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

    print("🧪 Windows System Audit Engine")
    print(f"Run ID: {run_id}")

    # ------------------------------------------------------
    # Execution
    # ------------------------------------------------------
    if args.module == "all":
        for module in MODULE_MAP:
            run_module(module, run_id)

        merge_reports(run_id)
        print("\n🎉 COMPREHENSIVE AUDIT DONE")

    else:
        run_module(args.module.lower(), run_id)

        if args.merge:
            merge_reports(run_id)
            print("\n🎉 SELECTED AUDIT DONE")


# ==========================================================
if __name__ == "__main__":
    main()
