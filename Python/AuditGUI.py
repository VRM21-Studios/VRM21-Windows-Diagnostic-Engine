```python
import sys
import shutil
import subprocess
import datetime
from pathlib import Path

from PySide6.QtCore import QThread, Signal
from PySide6.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QPushButton,
    QCheckBox,
    QTextEdit,
    QLabel
)


# ==========================================================
# PATH RESOLUTION (PyInstaller Safe)
# ==========================================================
def get_base_dir():
    if getattr(sys, "frozen", False):
        # Running as a packaged executable.
        return Path(sys.executable).parent

    # Running directly as a Python script.
    return Path(__file__).resolve().parent


BASE_DIR = get_base_dir()
PS_DIR = BASE_DIR / "Diagnostics"
ENGINE_PATH = BASE_DIR / "SystemAudit.py"

if not PS_DIR.exists():
    raise RuntimeError(f"Diagnostics directory not found: {PS_DIR}")


# ==========================================================
# MODULE DISCOVERY
# ==========================================================
def discover_modules():
    modules = []

    for ps in PS_DIR.glob("*-Diagnostic.ps1"):
        # Normalize module names to match SystemAudit.py arguments.
        name = ps.stem.replace("-Diagnostic", "").lower()
        modules.append(name)

    return sorted(modules)


MODULES = discover_modules()


# ==========================================================
# WORKER
# ==========================================================
class AuditWorker(QThread):
    log_signal = Signal(str)
    done_signal = Signal()

    def __init__(self, modules):
        super().__init__()
        self.modules = modules

    def run(self):
        run_id = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

        # Resolve the Python executable used to launch the audit engine.
        if getattr(sys, "frozen", False):
            python_cmd = shutil.which("python") or shutil.which("python3")
        else:
            python_cmd = sys.executable

        if not python_cmd:
            self.log_signal.emit("❌ Python not found in PATH.")
            self.done_signal.emit()
            return

        total = len(self.modules)

        for i, module in enumerate(self.modules, 1):
            self.log_signal.emit(
                f"\n▶ Starting audit: {module.upper()}"
            )

            if not ENGINE_PATH.exists():
                self.log_signal.emit("❌ SystemAudit.py missing.")
                continue

            cmd = [
                python_cmd,
                str(ENGINE_PATH),
                "--module", module,
                "--run-id", run_id
            ]

            # Merge reports only after the last selected module.
            if i == total:
                cmd.append("--merge")

            flags = 0

            # Prevent a command prompt window from appearing during
            # subprocess execution on Windows.
            if sys.platform.startswith("win"):
                flags = subprocess.CREATE_NO_WINDOW

            try:
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    creationflags=flags
                )

                # Forward audit engine output to the GUI log.
                if result.stdout:
                    self.log_signal.emit(result.stdout.strip())

                if result.stderr:
                    self.log_signal.emit(
                        f"⚠ ERROR:\n{result.stderr.strip()}"
                    )

            except Exception as e:
                self.log_signal.emit(
                    f"❌ Subprocess failed: {str(e)}"
                )

        self.done_signal.emit()


# ==========================================================
# GUI
# ==========================================================
class AuditGUI(QWidget):

    def __init__(self):
        super().__init__()
        self.setWindowTitle("Windows System Audit Tool")
        self.resize(900, 600)
        self._build_ui()

    def _build_ui(self):
        main = QHBoxLayout(self)

        # LEFT PANEL
        left = QVBoxLayout()
        self.checkboxes = {}

        for m in MODULES:
            cb = QCheckBox(m.upper())
            cb.setChecked(True)
            self.checkboxes[m] = cb
            left.addWidget(cb)

        left.addStretch()

        btn_all = QPushButton("✔ Check All")
        btn_none = QPushButton("✖ Uncheck All")
        btn_run = QPushButton("▶ Run Audit")

        btn_all.clicked.connect(self.check_all)
        btn_none.clicked.connect(self.uncheck_all)
        btn_run.clicked.connect(self.run_audit)

        left.addWidget(btn_all)
        left.addWidget(btn_none)
        left.addWidget(btn_run)

        # RIGHT PANEL
        right = QVBoxLayout()
        self.log = QTextEdit()
        self.log.setReadOnly(True)

        # Use a monospace font and terminal-style appearance for the log.
        self.log.setStyleSheet(
            "font-family: Consolas, monospace; "
            "font-size: 10pt; "
            "background-color: #1e1e1e; "
            "color: #d4d4d4;"
        )

        right.addWidget(QLabel("Audit Progress & Logs"))
        right.addWidget(self.log)

        main.addLayout(left, 1)
        main.addLayout(right, 2)

    def check_all(self):
        for cb in self.checkboxes.values():
            cb.setChecked(True)

    def uncheck_all(self):
        for cb in self.checkboxes.values():
            cb.setChecked(False)

    def run_audit(self):
        modules = [
            m for m, cb in self.checkboxes.items()
            if cb.isChecked()
        ]

        if not modules:
            self.log.append("⚠ No modules selected.")
            return

        self.log.append(
            "🧪 Starting Windows System Audit...\n"
        )

        # Disable all buttons while the audit is running.
        for btn in self.findChildren(QPushButton):
            btn.setEnabled(False)

        self.worker = AuditWorker(modules)
        self.worker.log_signal.connect(self.log.append)
        self.worker.done_signal.connect(self.audit_done)
        self.worker.start()

    def audit_done(self):
        self.log.append(
            "\n🎉 Audit finished. Report generated and JSON extracted."
        )

        # Re-enable all buttons after the audit completes.
        for btn in self.findChildren(QPushButton):
            btn.setEnabled(True)


# ==========================================================
if __name__ == "__main__":
    app = QApplication(sys.argv)

    # Use the Fusion style for consistent cross-platform rendering.
    app.setStyle("Fusion")

    win = AuditGUI()
    win.show()
    sys.exit(app.exec())
```
