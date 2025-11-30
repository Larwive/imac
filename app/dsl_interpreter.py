from typing import List, Dict

def parse(script: str) -> List[Dict]:
    """
    Temporary simple DSL parser.
    TODO: Use regex.
    """
    steps = []
    lines = [l.strip() for l in script.splitlines() if l.strip() and not l.strip().startswith("#")]
    for line in lines:
        parts = line.split()
        cmd = parts[0].lower()
        if cmd == "click":
            x = float(parts[1]) if len(parts) > 1 else 0.0
            y = float(parts[2]) if len(parts) > 2 else 0.0
            delay = float(parts[3]) if len(parts) > 3 else 0.0
            steps.append({"command": "Click", "x": x, "y": y, "delay": delay})
        elif cmd == "move":
            x = float(parts[1]) if len(parts) > 1 else 0.0
            y = float(parts[2]) if len(parts) > 2 else 0.0
            delay = float(parts[3]) if len(parts) > 3 else 0.0
            steps.append({"command": "Move", "x": x, "y": y, "delay": delay})
        elif cmd == "mousedown":
            x = float(parts[1]) if len(parts) > 1 else 0.0
            y = float(parts[2]) if len(parts) > 2 else 0.0
            steps.append({"command": "MouseDown", "x": x, "y": y})
        elif cmd == "mouseup":
            steps.append({"command": "MouseUp"})
        elif cmd == "repeat":
            # TODO
            pass
        else:
            continue
    return steps