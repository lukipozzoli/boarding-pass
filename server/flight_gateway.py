"""Pasarela local de desarrollo. Las claves de los proveedores nunca llegan al cliente iOS."""
from __future__ import annotations

import argparse
import json
import os
import re
import threading
import time
from datetime import date, datetime, time as day_time, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, quote, urlencode, urlparse
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo
from pathlib import Path

try:
    from .gateway_support import GatewayError, iso
    from .environment import load_environment_file
except ImportError:
    from gateway_support import GatewayError, iso
    from environment import load_environment_file

UTC = timezone.utc



def fixture_flight(selected_date: date) -> dict:
    """Respuesta sintética con campos de AeroAPI, sin llamadas al proveedor."""
    departure = datetime.combine(selected_date, day_time(18), ZoneInfo("America/Argentina/Buenos_Aires"))
    airport = lambda code, city: {"code": code, "code_iata": code, "city": city, "name": city, "timezone": "America/Argentina/Buenos_Aires"}
    return {
        "fa_flight_id": "fixture-AR1490", "ident": "ARG1490", "ident_iata": "AR1490", "operator_iata": "AR",
        "origin": airport("AEP", "Buenos Aires"), "destination": airport("SLA", "Salta"),
        "scheduled_out": iso(departure), "scheduled_in": iso(departure + timedelta(minutes=130)),
        "estimated_out": iso(departure + timedelta(minutes=20)), "estimated_in": iso(departure + timedelta(minutes=150)),
        "gate_origin": "7", "gate_destination": None, "terminal_origin": "A", "terminal_destination": None,
        "cancelled": False, "diverted": False, "aircraft_type": "A320", "route_distance": 795,
    }


class AeroAPIClient:
    def __init__(self, api_key: str, max_requests: int = 20, opener=urlopen, clock=time.monotonic):
        self.api_key = api_key
        self.max_requests = max_requests
        self.opener = opener
        self.clock = clock
        self.cache: dict[str, tuple[float, dict]] = {}
        self.requests: list[float] = []
        self.lock = threading.Lock()

    def get(self, identifier: str, parameters: dict) -> dict:
        if not self.api_key:
            raise GatewayError(503, "Falta configurar la clave de AeroAPI en el servidor.")
        url = "https://aeroapi.flightaware.com/aeroapi/flights/" + quote(identifier, safe="") + "?" + urlencode({**parameters, "max_pages": 1})
        # Serializar consultas iguales impide que dos clientes dupliquen el costo.
        with self.lock:
            now = self.clock()
            self.cache = {key: value for key, value in self.cache.items() if now - value[0] < 60}
            if url in self.cache:
                return self.cache[url][1]
            self.requests = [instant for instant in self.requests if now - instant < 60]
            if len(self.requests) >= self.max_requests:
                raise GatewayError(429, "Límite local de consultas alcanzado.")
            self.requests.append(now)
            request = Request(url, headers={"x-apikey": self.api_key, "Accept": "application/json"})
            try:
                with self.opener(request, timeout=15) as response:
                    payload = json.load(response)
            except HTTPError as error:
                status = 503 if error.code in (401, 403) else 429 if error.code == 429 else 502
                raise GatewayError(status, "No se pudo consultar AeroAPI.") from None
            except (URLError, TimeoutError, ValueError, OSError):
                raise GatewayError(502, "El proveedor no respondió correctamente.") from None
            if not isinstance(payload, dict) or not isinstance(payload.get("flights"), list):
                raise GatewayError(502, "Respuesta no válida del proveedor.")
            # No registrar cabeceras, claves ni cuerpos de respuesta.
            result = {"flights": payload["flights"], "links": payload.get("links"), "mode": "flightaware", "retrieved_at": iso(datetime.now(UTC))}
            self.cache[url] = (self.clock(), result)
            return result


class FlightGateway:
    def __init__(self, client: AeroAPIClient | None = None):
        self.client = client

    def handle(self, path: str, parameters: dict[str, list[str]], now: datetime | None = None) -> dict:
        now = now or datetime.now(UTC)
        if path == "/health":
            return {"status": "ok", "mode": "flightaware" if self.client else "fixture"}
        if path == "/v1/flights":
            number = parameters.get("number", [""])[0].upper().replace(" ", "")
            if not re.fullmatch(r"[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?", number):
                raise GatewayError(400, "Ingrese un número de vuelo válido.")
            try:
                selected_date = date.fromisoformat(parameters.get("date", [""])[0])
            except ValueError:
                raise GatewayError(422, "Fecha no válida.") from None
            if self.client is None:
                flights = [fixture_flight(selected_date)] if number in ("AR1490", "ARG1490") else []
                return {"flights": flights, "links": None, "mode": "fixture", "retrieved_at": iso(now)}
            if not now.date() - timedelta(days=9) <= selected_date <= now.date() + timedelta(days=1):
                raise GatewayError(422, "Fecha fuera de la ventana admitida.")
            # Cubrir el día local en distintas zonas sin exceder los límites de AeroAPI.
            start = max(datetime.combine(selected_date, day_time(), UTC) - timedelta(hours=14), now - timedelta(days=9, hours=23))
            end = min(datetime.combine(selected_date + timedelta(days=1), day_time(), UTC) + timedelta(hours=14), now + timedelta(days=1, hours=23))
            result = self.client.get(number, {"ident_type": "designator", "start": iso(start), "end": iso(end)})
            filtered = [flight for flight in result["flights"] if self.local_departure_date(flight) == selected_date]
            return {**result, "flights": filtered}
        if path == "/v1/flight":
            identifier = parameters.get("id", [""])[0]
            if not re.fullmatch(r"[A-Za-z0-9_.:-]{1,200}", identifier):
                raise GatewayError(400, "Identificador inválido.")
            if self.client is None:
                raise GatewayError(404, "La demostración no actualiza vuelos reales.")
            return self.client.get(identifier, {"ident_type": "fa_flight_id"})
        raise GatewayError(404, "Ruta no encontrada.")

    @staticmethod
    def local_departure_date(flight: dict) -> date | None:
        try:
            timestamp = datetime.fromisoformat(flight["scheduled_out"].replace("Z", "+00:00"))
            zone = (flight.get("origin") or {}).get("timezone")
            return timestamp.astimezone(ZoneInfo(zone) if zone else UTC).date()
        except (KeyError, ValueError, TypeError):
            return None


def make_handler(gateway: FlightGateway):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            parsed = urlparse(self.path)
            try:
                if len(self.path) > 2048:
                    raise GatewayError(400, "Consulta demasiado larga.")
                result = gateway.handle(parsed.path, parse_qs(parsed.query))
                status = 200
            except GatewayError as error:
                result, status = {"error": error.message}, error.status
            payload = json.dumps(result).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, *_):
            pass
    return Handler


def main():
    parser = argparse.ArgumentParser(description="Pasarela de desarrollo de Boarding Pass (solo loopback).")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--live", action="store_true", help="Habilitar consultas reales al proveedor seleccionado.")
    parser.add_argument("--provider", choices=["aviationstack", "flightaware"], default="aviationstack")
    args = parser.parse_args()
    try:
        load_environment_file(Path(__file__).resolve().parent.parent / ".env")
    except ValueError as error:
        parser.error(str(error))
    if not args.live:
        gateway = FlightGateway()
    elif args.provider == "aviationstack":
        try:
            from .aviationstack import AviationstackClient, AviationstackGateway
        except ImportError:
            from aviationstack import AviationstackClient, AviationstackGateway
        key = os.environ.get("AVIATIONSTACK_KEY", "")
        if not key:
            parser.error("Configure AVIATIONSTACK_KEY antes de habilitar --live.")
        gateway = AviationstackGateway(AviationstackClient(key))
    else:
        key = os.environ.get("AEROAPI_KEY", "")
        if not key:
            parser.error("Configure AEROAPI_KEY antes de habilitar --live.")
        gateway = FlightGateway(AeroAPIClient(key))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(gateway))
    print(f"Boarding Pass: http://localhost:{args.port} — {args.provider if args.live else 'DEMOSTRACIÓN, sin consultas externas'}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
