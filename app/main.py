import sys
import traceback
from pathlib import Path
from PySide6.QtWidgets import QApplication, QMainWindow, QTextEdit, QPushButton, QVBoxLayout, QWidget, QLabel, QHBoxLayout
from PySide6.QtCore import Qt, QObject, Signal, Slot, QThread
from app.script_manager import start_script_text, stop_runner

import logging
logging.basicConfig(level=logging.DEBUG, filename="app-debug.log", filemode="a",
                    format="%(asctime)s %(levelname)s %(name)s: %(message)s")

ROOT = Path(__file__).parent

SAMPLE = """click 216 659 22
click 216 659 6
click 216 659 6
"""

class Worker(QObject):
    finished = Signal()
    error = Signal(str)
    status = Signal(str)

    def __init__(self, script_text: str):
        super().__init__()
        self.script_text = script_text

    @Slot()
    def run(self):
        try:
            self.status.emit("Démarrage...")
            start_script_text(self.script_text)
            self.status.emit("Terminé.")
        except Exception:
            tb = traceback.format_exc()
            self.error.emit(tb)
        finally:
            self.finished.emit()

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Imac — iOS Mirroring Auto Clicker")
        self.resize(700, 500)

        self.editor = QTextEdit()
        self.editor.setPlainText(SAMPLE)

        self.run_btn = QPushButton("Run")
        self.stop_btn = QPushButton("Stop")
        self.status = QLabel("Prêt")
        self.status.setAlignment(Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft)

        btn_layout = QHBoxLayout()
        btn_layout.addWidget(self.run_btn)
        btn_layout.addWidget(self.stop_btn)
        btn_layout.addWidget(self.status, stretch=1)

        layout = QVBoxLayout()
        layout.addWidget(self.editor)
        layout.addLayout(btn_layout)

        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)

        self.run_btn.clicked.connect(self.on_run)
        self.stop_btn.clicked.connect(self.on_stop)

        self.worker_thread = None
        self.worker = None
        self._is_running = False

    def _set_running(self, value: bool):
        self._is_running = value
        self.run_btn.setEnabled(not value)
        self.stop_btn.setEnabled(value)

    def on_run(self):
        if self._is_running:
            self.status.setText("Déjà en cours.")
            return
        script = self.editor.toPlainText()
        self.status.setText("Démarrage…")

        # create thread + worker
        thread = QThread()
        worker = Worker(script)
        worker.moveToThread(thread)

        # connections
        thread.started.connect(worker.run)
        thread.started.connect(lambda: self._set_running(True))

        worker.finished.connect(lambda: self.status.setText("Terminé."))
        worker.finished.connect(lambda: thread.quit())
        worker.finished.connect(worker.deleteLater)

        worker.error.connect(lambda err: (self.status.setText("Erreur. Voir console."), print(err)))
        worker.status.connect(lambda s: self.status.setText(s))

        thread.finished.connect(lambda: self._on_thread_finished(thread))

        self.worker_thread = thread
        self.worker = worker

        thread.start()

    def _on_thread_finished(self, thread_obj):
        self._set_running(False)

        self.worker_thread = None
        self.worker = None
        self.status.setText("Arrêté.")

    def on_stop(self):
        stop_runner()
        self.status.setText("Stop demandé.")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = MainWindow()
    w.show()
    sys.exit(app.exec())