import io
import json
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from server.aviationstack import AviationstackClient, AviationstackGateway, decode_operation_id, normalize_flight
from server.environment import load_environment_file
from server.gateway_support import GatewayError

RECORD = {
    "flight_date": "2026-10-23", "flight_status": "active",
    "departure": {"iata": "AEP", "icao": "SABE", "airport": "Jorge Newbery", "timezone": "America/Argentina/Buenos_Aires", "scheduled": "2026-10-23T18:00:00-03:00", "estimated": "2026-10-23T18:20:00-03:00", "gate": "7", "terminal": "A"},
    "arrival": {"iata": "BRC", "icao": "SAZS", "airport": "Bariloche", "timezone": "America/Argentina/Buenos_Aires", "scheduled": "2026-10-23T20:25:00-03:00"},
    "flight": {"iata": "JA3053", "icao": "JAT3053"}, "airline": {"name": "JetSMART", "iata": "JA"}, "aircraft": None,
}
NOW = datetime(2026, 10, 23, 20, tzinfo=timezone.utc)


class AviationstackTests(unittest.TestCase):
    def test_normalizes_source_without_inventing_gate_events_or_distance(self):
        result = normalize_flight(RECORD)
        self.assertEqual(result["operator_name"], "JetSMART")
        self.assertEqual(result["normalized_status"], "inAir")
        self.assertEqual(result["time_basis"], "airport")
        self.assertIsNone(result["route_distance"])
        self.assertIsNone(result["actual_in"])
        self.assertEqual(decode_operation_id(result["fa_flight_id"]), ["JA3053", "2026-10-23", "AEP", "BRC"])

    def test_cache_prevents_repeated_requests_and_keeps_key_out_of_results(self):
        calls = []
        def opener(request, timeout):
            calls.append(request)
            self.assertEqual(urlparse(request.full_url).scheme, "https")
            query = parse_qs(urlparse(request.full_url).query)
            self.assertEqual(query["flight_iata"], ["JA3053"])
            self.assertNotIn("flight_date", query)
            return io.BytesIO(json.dumps({"data": [RECORD], "pagination": {"offset": 0, "count": 1, "total": 2}}).encode())
        client = AviationstackClient("fake-secret", opener=opener, max_session_requests=1)
        result = client.search("JA3053")
        self.assertEqual(client.search("JA3053"), result)
        self.assertEqual(len(calls), 1)
        self.assertNotIn("fake-secret", json.dumps(result))
        self.assertTrue(result["links"]["next"])
        with self.assertRaises(GatewayError) as error:
            client.search("AR1490")
        self.assertEqual(error.exception.status, 429)

    def test_provider_error_inside_http_200_is_not_an_empty_success(self):
        def opener(*args, **kwargs):
            return io.BytesIO(json.dumps({"error": {"code": 101, "type": "invalid_access_key", "info": "fake-secret"}}).encode())
        with self.assertRaises(GatewayError) as error:
            AviationstackClient("fake-secret", opener=opener).search("JA3053")
        self.assertEqual(error.exception.status, 503)
        self.assertNotIn("fake-secret", error.exception.message)

    def test_refresh_resolves_same_operation_and_free_plan_rejects_other_days(self):
        class FakeClient:
            def search(self, number):
                return {"flights": [normalize_flight(RECORD)], "mode": "aviationstack"}
        gateway = AviationstackGateway(FakeClient())
        operation = normalize_flight(RECORD)["fa_flight_id"]
        result = gateway.handle("/v1/flight", {"id": [operation]}, NOW)
        self.assertEqual(result["flights"][0]["fa_flight_id"], operation)
        with self.assertRaises(GatewayError) as error:
            gateway.handle("/v1/flights", {"number": ["JA3053"], "date": ["2026-10-22"]}, NOW)
        self.assertEqual(error.exception.status, 422)

    def test_env_loader_never_executes_and_preserves_existing_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env"
            path.write_text('export AVIATIONSTACK_KEY="fake-value" # comment\nOTHER=$(not-a-command)\n')
            environment = {"AVIATIONSTACK_KEY": "already-configured"}
            load_environment_file(path, environment)
            self.assertEqual(environment["AVIATIONSTACK_KEY"], "already-configured")
            self.assertEqual(environment["OTHER"], "$(not-a-command)")

    def test_env_errors_never_echo_values(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env"
            path.write_text('AVIATIONSTACK_KEY="fake-secret\n')
            with self.assertRaises(ValueError) as error:
                load_environment_file(path, {})
            self.assertNotIn("fake-secret", str(error.exception))


if __name__ == "__main__":
    unittest.main()
