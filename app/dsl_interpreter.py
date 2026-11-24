class DSLError(ValueError):
    def __init__(self, line_no: int, message: str):
        super().__init__(f"Line {line_no} : {message}")


def _num(parts, i, line_no, default=0.0):
    if len(parts) <= i:
        return default
    try:
        return float(parts[i])
    except ValueError:
        raise DSLError(line_no, f"expected number, got {parts[i]!r}")


def parse(script: str) -> list[dict]:
    """
    DSL parser.
    TODO: Use regex.
    """
    steps: list[dict] = []
    open_repeats: list[int] = []  # Line of unclosed repeats.

    for line_no, raw in enumerate(script.splitlines(), start=1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        cmd = parts[0].lower()

        if cmd in ("click", "move"):
            steps.append({"command": cmd.capitalize(),
                          "x": _num(parts, 1, line_no), "y": _num(parts, 2, line_no),
                          "time": _num(parts, 3, line_no)})
        elif cmd == "mousedown":
            steps.append({"command": "MouseDown",
                          "x": _num(parts, 1, line_no), "y": _num(parts, 2, line_no)})
        elif cmd == "mouseup":
            steps.append({"command": "MouseUp"})
        elif cmd == "sleep":
            steps.append({"command": "Sleep", "delay": _num(parts, 1, line_no)})
        elif cmd == "repeat":
            count = _num(parts, 1, line_no, default=-1)
            if count < 0 or count != int(count):
                raise DSLError(line_no, "'repeat' expects a positive int (0)")
            open_repeats.append(line_no)
            steps.append({"command": "Repeat", "count": int(count)})
        elif cmd == "end":
            if not open_repeats:
                raise DSLError(line_no, "'end' without corresponding 'repeat'.")
            open_repeats.pop()
            steps.append({"command": "End"})
        else:
            raise DSLError(line_no, f"Unknown command : {parts[0]!r}")

    if open_repeats:
        raise DSLError(open_repeats[-1], "Unclosed 'repeat', you forgot an 'end'.")
    return steps