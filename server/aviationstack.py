"""Adaptador HTTPS de Aviationstack. Normaliza datos para la pasarela local."""
from __future__ import annotations

import base64
import json
import re
import threading
import time
from datetime import date, datetime, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener
from zoneinfo import ZoneInfo

try:
    from .gateway_support import GatewayError, iso
except ImportError:
    from gateway_support import GatewayError, iso


class NoCredentialRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def operation_id(number, flight_date, origin, destination):
    fields = [number, flight_date, origin, destination]
    return "avs_" + base64.urlsafe_b64encode(json.dumps(fields, separators=(",", ":")).encode()).decode().rstrip("=")


def decode_operation_id(identifier):
    if not re.fullmatch(r"avs_[A-Za-z0-9_-]{1,196}", identifier):
        raise GatewayError(400, "Identificador de Aviationstack inválido.")
    try:
        token = identifier[4:]
        fields = json.loads(base64.urlsafe_b64decode(token + "=" * (-len(token) % 4)))
        if not isinstance(fields, list) or len(fields) != 4 or not all(isinstance(value, str) for value in fields):
            raise ValueError()
        if not re.fullmatch(r"[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?", fields[0]):
            raise ValueError()
        date.fromisoformat(fields[1])
        return fields
    except (ValueError, TypeError, UnicodeError):
        raise GatewayError(400, "Identificador de Aviationstack inválido.") from None


def normalize_flight(record):
    departure = record.get("departure") or {}
    arrival = record.get("arrival") or {}
    flight = record.get("flight") or {}
    airline = record.get("airline") or {}
    aircraft = record.get("aircraft") or {}
    number = flight.get("iata") or flight.get("icao")
    origin = departure.get("iata") or departure.get("icao")
    destination = arrival.get("iata") or arrival.get("icao")
    flight_date = record.get("flight_date")
    if not all(isinstance(value, str) and value for value in [number, origin, destination, flight_date]):
        return None

    def airport(reference):
        return {"code": reference.get("icao"), "code_iata": reference.get("iata"), "name": reference.get("airport"), "city": None, "timezone": reference.get("timezone")}

    status = record.get("flight_status")
    # Aviationstack no identifica estos horarios como eventos de puerta.
    return {
        "fa_flight_id": operation_id(number, flight_date, origin, destination),
        "ident": flight.get("icao") or number, "ident_iata": flight.get("iata"),
        "operator_iata": airline.get("iata"), "operator_name": airline.get("name"),
        "origin": airport(departure), "destination": airport(arrival),
        "scheduled_out": departure.get("scheduled"), "scheduled_in": arrival.get("scheduled"),
        "estimated_out": departure.get("estimated"), "estimated_in": arrival.get("estimated"),
        "actual_out": departure.get("actual"), "actual_in": arrival.get("actual"),
        "gate_origin": departure.get("gate"), "gate_destination": arrival.get("gate"),
        "terminal_origin": departure.get("terminal"), "terminal_destination": arrival.get("terminal"),
        "aircraft_type": aircraft.get("icao") or aircraft.get("iata"), "route_distance": None,
        "normalized_status": {"active": "inAir", "landed": "landed", "cancelled": "cancelled", "diverted": "diverted"}.get(status),
        "time_basis": "airport", "flight_date": flight_date,
    }


class AviationstackClient:
    def __init__(self, api_key, opener=None, clock=time.monotonic, max_session_requests=10):
        self.api_key = api_key
        self.opener = opener or build_opener(NoCredentialRedirect()).open
        self.clock = clock
        self.max_session_requests = max_session_requests
        self.request_count = 0
        self.cache = {}
        self.lock = threading.Lock()

    def search(self, number):
        if not self.api_key:
            raise GatewayError(503, "Falta configurar AVIATIONSTACK_KEY en el servidor.")
        if not re.fullmatch(r"[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?", number):
            raise GatewayError(400, "Número de vuelo inválido.")
        parameter = "flight_icao" if re.fullmatch(r"[A-Z]{3}[0-9]+[A-Z]?", number) else "flight_iata"
        with self.lock:
            cached = self.cache.get(number)
            if cached and self.clock() - cached[0] < 300:
                return cached[1]
            if self.request_count >= self.max_session_requests:
                raise GatewayError(429, "Se alcanzó el límite local de 10 consultas de esta sesión.")
            self.request_count += 1
            url = "https://api.aviationstack.com/v1/flights?" + urlencode({"access_key": self.api_key, parameter: number, "limit": 100})
            request = Request(url, headers={"Accept": "application/json"})
            try:
                with self.opener(request, timeout=20) as response:
                    payload = json.load(response)
            except HTTPError as error:
                try:
                    payload = json.load(error)
                except (ValueError, OSError):
                    raise GatewayError(502, "Aviationstack no devolvió una respuesta válida.") from None
                self.raise_provider_error(payload, error.code)
                raise GatewayError(502, "No se pudo consultar Aviationstack.") from None
            except (URLError, TimeoutError, OSError, ValueError):
                raise GatewayError(502, "No se pudo consultar Aviationstack por HTTPS.") from None
            self.raise_provider_error(payload)
            if not isinstance(payload, dict) or not isinstance(payload.get("data"), list):
                raise GatewayError(502, "Respuesta de Aviationstack no válida.")
            records = [normalize_flight(record) for record in payload["data"] if isinstance(record, dict)]
            pagination = payload.get("pagination") or {}
            has_more = pagination.get("offset", 0) + pagination.get("count", len(records)) < pagination.get("total", len(records))
            result = {
                "flights": [record for record in records if record is not None],
                "links": {"next": "partial"} if has_more else None,
                "mode": "aviationstack", "retrieved_at": iso(datetime.now(timezone.utc)),
                "omitted_records": sum(record is None for record in records),
            }
            self.cache[number] = (self.clock(), result)
            return result

    @staticmethod
    def raise_provider_error(payload, http_status=200):
        error = payload.get("error") if isinstance(payload, dict) else None
        if not error:
            return
        error_type = error.get("type") if isinstance(error, dict) else None
        code = error.get("code") if isinstance(error, dict) else None
        if error_type in ["usage_limit_reached", "rate_limit_reached"] or code == 104 or http_status == 429:
            raise GatewayError(429, "Se alcanzó el límite de consultas de Aviationstack.")
        if error_type in ["function_access_restricted", "https_access_restricted", "subscription_inactive", "historical_api_restricted"] or code == 105:
            raise GatewayError(402, "Su plan de Aviationstack no permite esta consulta. No se intentó otra API ni HTTP sin cifrar.")
        if error_type in ["invalid_access_key", "missing_access_key", "inactive_user"] or code in [101, 102] or http_status in [401, 403]:
            raise GatewayError(503, "Aviationstack no aceptó la clave configurada.")
        raise GatewayError(502, "Aviationstack rechazó la consulta.")


class AviationstackGateway:
    def __init__(self, client):
        self.client = client

    def handle(self, path, parameters, now=None):
        now = now or datetime.now(timezone.utc)
        if path == "/health":
            return {"status": "ok", "mode": "aviationstack"}
        if path == "/v1/flights":
            number = parameters.get("number", [""])[0].upper().replace(" ", "")
            try:
                selected_date = date.fromisoformat(parameters.get("date", [""])[0])
            except ValueError:
                raise GatewayError(422, "Fecha no válida.") from None
            # El plan gratuito se limita a datos actuales, sin usar flight_date histórico.
            if selected_date != now.astimezone(ZoneInfo("America/Argentina/Buenos_Aires")).date():
                raise GatewayError(422, "La conexión gratuita de Aviationstack solo consulta vuelos de hoy.")
            result = self.client.search(number)
            return {**result, "flights": [record for record in result["flights"] if record["flight_date"] == selected_date.isoformat()]}
        if path == "/v1/flight":
            identifier = parameters.get("id", [""])[0]
            number, flight_date, _, _ = decode_operation_id(identifier)
            result = self.handle("/v1/flights", {"number": [number], "date": [flight_date]}, now)
            return {**result, "flights": [record for record in result["flights"] if record["fa_flight_id"] == identifier]}
        raise GatewayError(404, "Ruta no encontrada.")
