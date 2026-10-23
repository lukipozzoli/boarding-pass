"""Carga un .env simple sin ejecutar comandos ni interpolar variables."""
import os
import re
import shlex
from pathlib import Path


def load_environment_file(path: Path, environment=None):
    environment = os.environ if environment is None else environment
    if not path.exists():
        return
    entries = {}
    for line_number, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        line = re.sub(r"^export\s+", "", line)
        name, separator, raw_value = line.partition("=")
        name = name.strip()
        if not separator or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            raise ValueError(f"Formato de .env no válido en la línea {line_number}.")
        try:
            values = shlex.split(raw_value, comments=True)
        except ValueError:
            raise ValueError(f"Comillas de .env no válidas en la línea {line_number}.") from None
        if len(values) > 1:
            raise ValueError(f"Use comillas para valores con espacios en la línea {line_number}.")
        entries[name] = values[0] if values else ""
    for name, value in entries.items():
        environment.setdefault(name, value)
