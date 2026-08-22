#!/usr/bin/env python3
import json
import os
import socket
import subprocess
import sys
import time

PLUGIN_ID = "bms.videocorner"
STATE_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", ""), PLUGIN_ID)
STATE_FILE = os.path.join(STATE_DIR, "player.address")
WATCHDOG_CLOSE = 5
WATCHDOG_OPEN = 8
POLL = 0.03


def state_dir():
    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)


def socket_path():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR", ""), "hypr", sig, ".socket2.sock")


def clients():
    out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True)
    try:
        return json.loads(out.stdout) or []
    except Exception:
        return []


def normalize_address(addr):
    addr = str(addr).strip()
    if addr and not addr.lower().startswith("0x"):
        addr = "0x" + addr
    return addr


def read_state():
    if not os.path.isfile(STATE_FILE):
        return ""
    return normalize_address(open(STATE_FILE).read().strip())


def write_state(addr):
    state_dir()
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        f.write(addr + "\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, STATE_FILE)


def clear_state():
    try:
        os.remove(STATE_FILE)
    except OSError:
        pass


def open_eventsocket():
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(socket_path())
        return s
    except OSError:
        return None


def read_events(pred, timeout, sock):
    """Feed event lines to pred; return the first non-None pred result."""
    sock.settimeout(0.1)
    deadline = time.monotonic() + timeout
    buf = ""
    while time.monotonic() < deadline:
        try:
            data = sock.recv(4096).decode()
            if not data:
                break
            buf += data
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                line = line.strip()
                if not line:
                    continue
                r = pred(line)
                if r is not None:
                    return r
        except socket.timeout:
            continue
        except OSError:
            break
    return None


def has_client(addr):
    return any(c.get("address") == addr for c in clients())


def wait_absent(addr, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if not has_client(addr):
            return True
        time.sleep(POLL)
    return False


def dispatch_lua(cmd):
    subprocess.run(["hyprctl", "dispatch", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def cmd_close():
    addr = read_state()
    if not addr:
        return 0
    if not has_client(addr):
        clear_state()
        return 0

    sock = open_eventsocket()
    dispatch_lua('hl.dsp.window.close({ window = "address:%s" })' % addr)
    closed = False
    if sock is not None:

        def match_close(line):
            if not line.startswith("closewindow>>"):
                return None
            return line if normalize_address(line.split(">>")[1]) == addr else None

        hit = read_events(match_close, WATCHDOG_CLOSE, sock)
        closed = hit is not None
        sock.close()
    if not closed:
        closed = wait_absent(addr, WATCHDOG_CLOSE)
    if not closed:
        subprocess.run(["hyprctl", "dispatch", "closewindow", "address:%s" % addr],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        closed = wait_absent(addr, 3)
    if closed:
        clear_state()
        return 0
    return 1


def apply_geometry(addr, x, y, w, h):
    window = "address:%s" % addr
    dispatch_lua('hl.dsp.window.float({ action = "enable", window = "%s" })' % window)
    time.sleep(0.05)
    dispatch_lua('hl.dsp.window.resize({ x = %s, y = %s, window = "%s" })' % (w, h, window))
    dispatch_lua('hl.dsp.window.move({ x = %s, y = %s, relative = false, window = "%s" })' % (x, y, window))
    dispatch_lua('hl.dsp.window.pin({ window = "%s" })' % window)
    dispatch_lua('hl.dsp.window.tag({ window = "%s", tag = "-default-opacity" })' % window)
    dispatch_lua('hl.dsp.window.set_prop({ window = "%s", prop = "opaque", value = 1 })' % window)
    dispatch_lua('hl.dsp.window.alter_zorder({ window = "%s", mode = "top" })' % window)
    dispatch_lua('hl.dsp.window.tag({ window = "%s", tag = "+pop" })' % window)

    target = next((c for c in clients() if c.get("address") == addr), None)
    if target:
        if tuple(target.get("at", [])) != (int(x), int(y)) or tuple(target.get("size", [])) != (int(w), int(h)):
            dispatch_lua('hl.dsp.window.resize({ x = %s, y = %s, window = "%s" })' % (w, h, window))
            dispatch_lua('hl.dsp.window.move({ x = %s, y = %s, relative = false, window = "%s" })' % (x, y, window))


def cmd_open(url, x, y, w, h):
    before = set(c.get("address") for c in clients())
    sock = open_eventsocket()
    subprocess.Popen(["chromium", "--app=" + url, "--no-first-run", "--no-default-browser-check"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    new_addr = None
    if sock is not None:
        def pred(line):
            if not line.startswith("openwindow>>"):
                return None
            parts = line[len("openwindow>>"):].split(",", 3)
            if len(parts) < 3:
                return None
            a = normalize_address(parts[0])
            if a in before:
                return None
            if "youtube" in parts[2].lower():
                return a
            return None
        new_addr = read_events(pred, WATCHDOG_OPEN, sock)
        sock.close()

    if not new_addr:
        deadline = time.monotonic() + WATCHDOG_OPEN
        while time.monotonic() < deadline:
            for c in clients():
                a = c.get("address")
                if a and a not in before and "youtube" in str(c.get("class", "")).lower():
                    new_addr = a
                    break
            if new_addr:
                break
            time.sleep(POLL)

    if not new_addr:
        return 1

    write_state(new_addr)
    apply_geometry(new_addr, x, y, w, h)
    return 0


def cmd_alive():
    addr = read_state()
    if not addr:
        return 1
    for c in clients():
        if c.get("address") == addr and c.get("mapped", False) and "youtube" in str(c.get("class", "")).lower():
            return 0
    return 1


def cmd_title():
    addr = read_state()
    if not addr:
        return 1
    for c in clients():
        if c.get("address") == addr and c.get("mapped", False) and "youtube" in str(c.get("class", "")).lower():
            print(str(c.get("title", "")))
            return 0
    clear_state()
    return 1


def cmd_position(x, y, w, h):
    addr = read_state()
    if not addr or not has_client(addr):
        return 0
    dispatch_lua('hl.dsp.window.resize({ x = %s, y = %s, window = "address:%s" })' % (w, h, addr))
    dispatch_lua('hl.dsp.window.move({ x = %s, y = %s, relative = false, window = "address:%s" })' % (x, y, addr))
    return 0


def main():
    args = sys.argv[1:]
    if not args:
        return 1
    cmd = args[0]
    if cmd == "close":
        return cmd_close()
    if cmd == "open" and len(args) == 6:
        return cmd_open(args[1], args[2], args[3], args[4], args[5])
    if cmd == "alive":
        return cmd_alive()
    if cmd == "title":
        return cmd_title()
    if cmd == "position" and len(args) == 5:
        return cmd_position(args[1], args[2], args[3], args[4])
    return 1


if __name__ == "__main__":
    sys.exit(main())
