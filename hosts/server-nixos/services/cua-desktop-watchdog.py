#!/usr/bin/env python3
"""Keep the Computer Use virtual desktop alive.

Hermes cron runs this as no_agent. Empty stdout = silent.
Processes are started in a new session so they survive the cron tick.

/tmp lives on the container overlay. A killed Xvfb leaves /tmp/.X99-lock,
and after a restart that PID is often a different process. Xvfb then
refuses the display. Drop the lock when no Xvfb for this display is alive.
"""
from __future__ import annotations

import os
import signal
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


def display_num() -> str | None:
    num = DISPLAY.rsplit(":", 1)[-1].split(".", 1)[0]
    if num.isdigit():
        return num
    return None


def cmdline(pid: int) -> list[str]:
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\x00")
    except OSError:
        return []
    return [part.decode(errors="replace") for part in raw if part]


def proc_named(name: str) -> bool:
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        argv = cmdline(int(entry.name))
        if argv and Path(argv[0]).name == name:
            return True
    return False


def xvfb_pids() -> list[int]:
    num = display_num()
    if num is None:
        return []
    needle = f":{num}"
    found: list[int] = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        argv = cmdline(pid)
        if not argv or Path(argv[0]).name != "Xvfb":
            continue
        if any(arg == needle or arg.startswith(needle + ".") for arg in argv):
            found.append(pid)
    return found


def clear_stale_x_lock() -> None:
    """Remove an X lock whose PID is not an Xvfb for this display.

    X only checks that the recorded PID exists. After a container restart
    the PID namespace is reused, so a dead server looks active.
    """
    if xvfb_pids():
        return
    num = display_num()
    if num is None:
        return
    for path in (Path(f"/tmp/.X{num}-lock"), Path(f"/tmp/.X11-unix/X{num}")):
        try:
            path.unlink()
        except OSError:
            pass


def stop_xvfb() -> None:
    def signal_all(sig: int) -> None:
        for pid in xvfb_pids():
            try:
                os.kill(pid, sig)
            except OSError:
                pass

    def wait_until_gone() -> bool:
        for _ in range(20):
            if not xvfb_pids():
                return True
            time.sleep(0.1)
        return not xvfb_pids()

    signal_all(signal.SIGTERM)
    if wait_until_gone():
        return
    signal_all(signal.SIGKILL)
    wait_until_gone()


def listening(port: int) -> bool:
    probe = socket.socket()
    probe.settimeout(0.4)
    try:
        return probe.connect_ex(("127.0.0.1", port)) == 0
    finally:
        probe.close()


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


def wait_x11(ticks: int = 50) -> bool:
    for _ in range(ticks):
        if x11_up():
            return True
        time.sleep(0.1)
    return x11_up()


started: list[str] = []

if not x11_up():
    # A live Xvfb that never bound the socket will not recover on its own.
    if xvfb_pids():
        wait_x11(20)
    if not x11_up():
        stop_xvfb()
        clear_stale_x_lock()
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
        started.append("Xvfb")
        wait_x11()

if x11_up() and not proc_named("fluxbox"):
    spawn(["fluxbox"], "fluxbox.log")
    started.append("fluxbox")

if x11_up() and PASSFILE.exists() and not listening(5900):
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
