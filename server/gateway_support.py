"""Tipos y formato compartidos por las pasarelas de proveedores."""
from datetime import datetime, timezone


class GatewayError(Exception):
    def __init__(self, status: int, message: str):
        self.status = status
        self.message = message


def iso(timestamp: datetime) -> str:
    return timestamp.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
