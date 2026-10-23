import io
import json
import unittest
from datetime import datetime, timezone
from urllib.error import HTTPError

from server.flight_gateway import AeroAPIClient, FlightGateway, GatewayError, fixture_flight

NOW = datetime(2026, 10, 23, 20, tzinfo=timezone.utc)


class GatewayTests(unittest.TestCase):
    def test_fixture_mode_never_uses_provider(self):
        response = FlightGateway().handle("/v1/flights", {"number": ["AR1490"], "date": ["2026-10-23"]}, NOW)
        self.assertEqual(response["mode"], "fixture")
        self.assertEqual(response["flights"][0]["ident_iata"], "AR1490")
        self.assertEqual(FlightGateway().handle("/v1/flights", {"number": ["AR1000"], "date": ["2026-10-23"]}, NOW)["flights"], [])

    def test_query_rejects_invalid_identifiers_before_provider_call(self):
        for value in ["../account", "", "AR1490?max_pages=100"]:
            with self.subTest(value=value), self.assertRaises(GatewayError) as error:
                FlightGateway().handle("/v1/flights", {"number": [value], "date": ["2026-10-23"]}, NOW)
            self.assertEqual(error.exception.status, 400)

    def test_live_date_limits_and_origin_local_day(self):
        class FakeClient:
            def get(self, *args):
                return {"flights": [fixture_flight(NOW.date())], "mode": "flightaware"}
        gateway = FlightGateway(FakeClient())
        with self.assertRaises(GatewayError) as error:
            gateway.handle("/v1/flights", {"number": ["AR1490"], "date": ["2026-12-01"]}, NOW)
        self.assertEqual(error.exception.status, 422)
        self.assertEqual(len(gateway.handle("/v1/flights", {"number": ["AR1490"], "date": ["2026-10-23"]}, NOW)["flights"]), 1)
        midnight = fixture_flight(NOW.date())
        midnight["scheduled_out"] = "2026-10-24T01:00:00Z"
        self.assertEqual(gateway.local_departure_date(midnight), NOW.date())

    def test_cache_rate_limit_and_single_page(self):
        calls = []
        def opener(request, timeout):
            calls.append(request)
            self.assertIn("max_pages=1", request.full_url)
            self.assertEqual(request.get_header("X-apikey"), "test-key")
            return io.BytesIO(json.dumps({"flights": [], "links": {"next": "more"}}).encode())
        client = AeroAPIClient("test-key", max_requests=1, opener=opener, clock=lambda: 100)
        first = client.get("ARG1490", {})
        self.assertEqual(client.get("ARG1490", {}), first)
        self.assertEqual(len(calls), 1)
        self.assertEqual(first["links"]["next"], "more")
        self.assertNotIn("test-key", json.dumps(first))
        with self.assertRaises(GatewayError) as error:
            client.get("ARG1400", {})
        self.assertEqual(error.exception.status, 429)

    def test_provider_authentication_errors_do_not_leak_secrets(self):
        def opener(*args, **kwargs):
            raise HTTPError("https://example.com", 401, "key=secret", {}, None)
        with self.assertRaises(GatewayError) as error:
            AeroAPIClient("secret", opener=opener).get("ARG1490", {})
        self.assertEqual(error.exception.status, 503)
        self.assertNotIn("secret", error.exception.message)

    def test_missing_key_does_not_open_network(self):
        def opener(*args, **kwargs):
            self.fail("No debe consultar la red")
        with self.assertRaises(GatewayError) as error:
            AeroAPIClient("", opener=opener).get("ARG1490", {})
        self.assertEqual(error.exception.status, 503)


if __name__ == "__main__":
    unittest.main()
