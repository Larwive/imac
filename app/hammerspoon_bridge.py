import subprocess
import tempfile
import json
import os
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

HS_CLI_CANDIDATES = ["/usr/local/bin/hs", "/opt/homebrew/bin/hs", "/usr/bin/hs"]

def _ensure_hammerspoon_running():
    subprocess.run(
        ["open", "-gja", "Hammerspoon"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

def _hs_cli():
    for p in HS_CLI_CANDIDATES:
        if Path(p).exists():
            return p
    raise FileNotFoundError("hs CLI not found. Install Hammerspoon and activate CLI (hs).")

def run_steps(steps):
    """
    Writes the steps to a temp file as JSON, then calls Hammerspoon CLI to run clicker.lua with those steps.
    """
    _ensure_hammerspoon_running()
    hs_cli = _hs_cli()
    tf = tempfile.NamedTemporaryFile(suffix=".json", delete=False)
    tf.write(json.dumps(steps).encode("utf-8"))
    tf.flush()
    tf.close()

    clicker_path = str(Path(__file__).resolve().parents[1] / "hammerspoon" / "clicker.lua")

    lua = (
        f"local f = io.open({json.dumps(tf.name)}, 'r'); local body = f:read('*a'); f:close(); "
        "local ok, j = pcall(require, 'json'); local steps = ok and j.decode(body) or (require('hs.json').decode(body)); "
        f"local ok2, clicker = pcall(dofile, {json.dumps(clicker_path)}); "
        "if ok2 and clicker and clicker.start then pcall(clicker.start, steps) else error('clicker module failed to load') end"
    )

    res = subprocess.run([hs_cli, "-c", lua], check=False, capture_output=True, text=True, env={**os.environ})
    if res.returncode != 0:
        logger.error("hs CLI returned %s\nstdout=%s\nstderr=%s", res.returncode, res.stdout, res.stderr)
        raise RuntimeError(f"hs CLI error: {res.stderr.strip()}")
    logger.debug("hs stdout: %s", res.stdout)


def stop():
    hs_cli = _hs_cli()
    clicker_path = str(Path(__file__).resolve().parents[1] / "hammerspoon" / "clicker.lua")
    lua = (
        f"local ok, clicker = pcall(dofile, {json.dumps(clicker_path)}); "
        "if ok and clicker and clicker.stop then pcall(clicker.stop) end"
    )
    subprocess.run([hs_cli, "-c", lua], check=False, capture_output=True, text=True, env={**os.environ})