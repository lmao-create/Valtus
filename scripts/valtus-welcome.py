#!/usr/bin/env python3
"""Valtus welcome application.

Shown at first login in the live session. Provides quick access to essential
applications and documents the live-session credentials (which are fixed,
documented demo credentials by design — see config/valtus.env and README.md).
"""
import os
import sys

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QFont, QIcon, QPixmap
from PyQt6.QtWidgets import (
    QApplication, QFrame, QGridLayout, QHBoxLayout, QLabel, QPushButton,
    QVBoxLayout, QWidget,
)

DISTRO_NAME = "Valtus"
DISTRO_VERSION = "0.1.0"
DISTRO_CODENAME = "granite"
LOGO_PATH = "/usr/share/valtus/logo.png"

LAUNCHERS = [
    ("Terminal", "konsole"),
    ("File Manager", "dolphin"),
    ("System Settings", "systemsettings"),
    ("Software Center", "plasma-discover"),
]


class Welcome(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(f"Welcome to {DISTRO_NAME}")
        self.setWindowIcon(QIcon(LOGO_PATH))
        self.setFixedSize(680, 460)

        palette = self.palette()
        palette.setColor(self.backgroundRole(), Qt.GlobalColor.darkGray)
        self.setAutoFillBackground(True)
        self.setPalette(palette)

        self.setStyleSheet("""
            QWidget { background-color: #1A212E; color: #E6EAF0; }
            QLabel#title { font-size: 24px; font-weight: 600; }
            QLabel#subtitle { color: #8792A6; font-size: 13px; }
            QLabel#body { font-size: 13px; line-height: 1.4; }
            QLabel#creds { color: #8792A6; font-size: 12px; }
            QPushButton {
                background-color: #3D6E9E; color: #FFFFFF;
                border: none; border-radius: 4px; padding: 8px 16px;
                font-size: 13px;
            }
            QPushButton:hover { background-color: #4A7FB5; }
            QFrame#line { color: #2A3549; }
        """)

        root = QVBoxLayout(self)
        root.setContentsMargins(28, 24, 28, 20)
        root.setSpacing(12)

        header = QHBoxLayout()
        logo = QLabel()
        if os.path.exists(LOGO_PATH):
            logo.setPixmap(QPixmap(LOGO_PATH).scaled(
                64, 64, Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation))
        titlebox = QVBoxLayout()
        title = QLabel(f"Welcome to {DISTRO_NAME}")
        title.setObjectName("title")
        subtitle = QLabel(f"Version {DISTRO_VERSION} '{DISTRO_CODENAME}' — "
                          "a professional, security-focused desktop")
        subtitle.setObjectName("subtitle")
        titlebox.addWidget(title)
        titlebox.addWidget(subtitle)
        header.addWidget(logo)
        header.addSpacing(12)
        header.addLayout(titlebox)
        header.addStretch(1)
        root.addLayout(header)

        line = QFrame()
        line.setObjectName("line")
        line.setFrameShape(QFrame.Shape.HLine)
        root.addWidget(line)

        body = QLabel(
            "This is a live session running from the Valtus image. "
            "Everything you do here is temporary unless you install the "
            "system to a disk.\n\n"
            "• Browse the web, manage files, and explore the desktop.\n"
            "• Install software from the software center.\n"
            "• Security: firewall active (no incoming connections), root "
            "locked, security updates enabled.")
        body.setObjectName("body")
        body.setWordWrap(True)
        root.addWidget(body)

        creds = QLabel(
            "Live login — user: valtus, password: valtus "
            "(documented live-only credentials; an installed system asks you "
            "to choose your own).")
        creds.setObjectName("creds")
        creds.setWordWrap(True)
        root.addWidget(creds)

        grid = QGridLayout()
        grid.setSpacing(10)
        for index, (label, command) in enumerate(LAUNCHERS):
            button = QPushButton(label)
            button.clicked.connect(lambda _, c=command: self.launch(c))
            grid.addWidget(button, index // 2, index % 2)
        root.addLayout(grid)
        root.addStretch(1)

        footer = QLabel("Based on Ubuntu 24.04 LTS. Valtus is not affiliated "
                        "with or endorsed by Canonical Ltd. or KDE.")
        footer.setObjectName("creds")
        root.addWidget(footer)

    def launch(self, command: str) -> None:
        from PyQt6.QtCore import QProcess
        QProcess.startDetached(command, [])


def main() -> int:
    QApplication.setAttribute(Qt.ApplicationAttribute.AA_UseHighDpiPixmaps)
    app = QApplication(sys.argv)
    font = QFont("Noto Sans", 10)
    app.setFont(font)
    window = Welcome()
    window.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
