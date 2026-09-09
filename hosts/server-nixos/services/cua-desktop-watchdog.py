#!/usr/bin/env python3
"""Keep the Computer Use virtual desktop alive.

Hermes cron runs this as no_agent. Empty stdout = silent.
Processes are started in a new session so they survive the cron tick.
"""
from __future__ import annotations

import os
import socket
import subprocess
import sys
import time
from pathlib import Path

DISPLAY = os.environ.get("DISPLAY", ":99")
LOG = Path("/data/.hermes/logs")
PASSFILE = Path("/data/.hermes/vnc.passwd")
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp/runtime-hermes"))
os.environ["DISPLAY"] = DISPLAY
os.environ.setdefault("XDG_RUNTIME_DIR", str(RUNTIME))
LOG.mkdir(parents=True, exist_ok=True)
RUNTIME.mkdir(parents=True, exist_ok=True)
try:
    RUNTIME.chmod(0o700)
except OSError:
    pass


def proc_named(name: str) -> bool:
    for d in Path("/proc").iterdir():
        if not d.name.isdigit():
            continue
        try:
            raw = (d / "cmdline").read_bytes().split(b"\x00")
            argv0 = (raw[0] if raw else b"").decode(errors="replace")
        except OSError:
            continue
        if Path(argv0).name == name:
            return True
    return False


def listening(port: int) -> bool:
    s = socket.socket()
    s.settimeout(0.4)
    try:
        return s.connect_ex(("127.0.0.1", port)) == 0
    finally:
        s.close()


def wait_port(port: int, ticks: int = 40) -> bool:
    for _ in range(ticks):
        if listening(port):
            return True
        time.sleep(0.1)
    return listening(port)


def spawn(argv: list[str], log_name: str) -> None:
    logf = (LOG / log_name).open("ab")
    subprocess.Popen(
        argv,
        stdout=logf,
        stderr=logf,
        stdin=subprocess.DEVNULL,
        start_new_session=True,
        env=os.environ.copy(),
    )


def x11_up() -> bool:
    return subprocess.call(
        ["xdpyinfo"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env={**os.environ, "DISPLAY": DISPLAY},
    ) == 0


started: list[str] = []

if not x11_up():
    spawn(
        [
            "Xvfb",
            DISPLAY,
            "-screen",
            "0",
            "1600x900x24",
            "-ac",
            "+extension",
            "RENDER",
            "+extension",
            "GLX",
            "+extension",
            "RANDR",
        ],
        "xvfb.log",
    )
    for _ in range(40):
        if x11_up():
            break
        time.sleep(0.1)
    started.append("Xvfb")

if not proc_named("fluxbox"):
    spawn(["fluxbox"], "fluxbox.log")
    started.append("fluxbox")

if PASSFILE.exists() and not listening(5900):
    spawn(
        [
            "x11vnc",
            "-display",
            DISPLAY,
            "-rfbport",
            "5900",
            "-rfbauth",
            str(PASSFILE),
            "-forever",
            "-shared",
            "-noxdamage",
            "-repeat",
            "-nowf",
            "-listen",
            "0.0.0.0",
        ],
        "x11vnc.log",
    )
    started.append("x11vnc")
    wait_port(5900)

if listening(5900) and not listening(6080):
    spawn(
        ["websockify", "--web", "/usr/share/novnc", "6080", "127.0.0.1:5900"],
        "novnc.log",
    )
    started.append("novnc")
    wait_port(6080)

# Silent when healthy. Nonzero if VNC or noVNC is still down after start.
if not listening(5900):
    print("cua-desktop: VNC :5900 not listening", file=sys.stderr)
    sys.exit(1)
if not listening(6080):
    print("cua-desktop: noVNC :6080 not listening", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
