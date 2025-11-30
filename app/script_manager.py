from .dsl_interpreter import parse
from .hammerspoon_bridge import run_steps, stop

def start_script_text(script_text: str):
    """
    Blocking. Run in a Thread for non-blocking version.
    App is supposed to use a Thread to call this function.
    """
    steps = parse(script_text)
    run_steps(steps)

def stop_runner():
    stop()