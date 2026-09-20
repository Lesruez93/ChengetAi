from pathlib import Path

SAMPLE_CSV = Path(__file__).resolve().parents[2] / "sample_data" / "transactions_sample.csv"


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert "KE" in body["countries"]


def test_classify_endpoint(client):
    resp = client.post("/classify", json={
        "text": "Pay $15 registration fee to secure your remote job slot.",
        "country": "ZW",
    })
    assert resp.status_code == 200
    body = resp.json()
    assert body["verdict"] in {"scam", "suspicious", "safe"}
    assert body["strategy_used"] == "baseline"
    assert body["country"] == "ZW"


def test_classify_defaults_country_when_omitted(client):
    resp = client.post("/classify", json={"text": "Send your PIN to verify your account."})
    assert resp.status_code == 200
    assert resp.json()["country"] == "ZW"


def test_report_then_lookup_number(client):
    report_resp = client.post("/reports", json={
        "msisdn": "0712223333", "country": "ZW", "category": "mobile_money_reversal",
        "region": "Harare", "message_excerpt": "reverse the money please",
    })
    assert report_resp.status_code == 200
    body = report_resp.json()
    assert body["status"] == "recorded"
    assert body["msisdn"] == "+263712223333"

    lookup_resp = client.get("/numbers/+263712223333")
    assert lookup_resp.status_code == 200
    assert lookup_resp.json()["report_count"] == 1


def test_lookup_local_number_requires_the_right_country(client):
    client.post("/reports", json={
        "msisdn": "0712223333", "country": "ZW", "category": "fake_job",
    })
    # Same local digits, read as Uganda — a different number, so no reports.
    resp = client.get("/numbers/0712223333", params={"country": "UG"})
    assert resp.status_code == 200
    assert resp.json()["msisdn"] == "+256712223333"
    assert resp.json()["report_count"] == 0


def test_lookup_invalid_number_returns_422(client):
    assert client.get("/numbers/123").status_code == 422


def test_lookup_unsupported_country_returns_422(client):
    resp = client.get("/numbers/0712345678", params={"country": "FR"})
    assert resp.status_code == 422


def test_list_numbers_endpoint_ranks_by_report_count(client):
    resp = client.get("/numbers")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) > 0
    counts = [n["report_count"] for n in body]
    assert counts == sorted(counts, reverse=True)


def test_list_numbers_can_be_scoped_to_a_market(client):
    resp = client.get("/numbers", params={"country": "KE"})
    assert resp.status_code == 200
    assert all("KE" in n["countries"] for n in resp.json())


def test_list_reports_endpoint_supports_filtering(client):
    resp = client.get("/reports")
    assert resp.status_code == 200
    assert len(resp.json()) > 0

    filtered = client.get("/reports", params={"category": "mobile_money_reversal"})
    assert filtered.status_code == 200
    assert all(r["category"] == "mobile_money_reversal" for r in filtered.json())

    by_country = client.get("/reports", params={"country": "NG"})
    assert by_country.status_code == 200
    assert by_country.json()
    assert all(r["country"] == "NG" for r in by_country.json())


def test_feed_and_trending_endpoints(client):
    assert client.get("/feed").status_code == 200

    trending_resp = client.get("/feed/trending")
    assert trending_resp.status_code == 200
    body = trending_resp.json()
    assert body["country_hotspots"]
    assert body["hotspots"] == []  # unscoped: no regional map

    scoped = client.get("/feed/trending", params={"country": "KE"})
    assert scoped.status_code == 200
    assert scoped.json()["hotspots"]
    assert scoped.json()["region_label"] == "Region"


def test_feed_trending_rejects_an_unsupported_country(client):
    assert client.get("/feed/trending", params={"country": "FR"}).status_code == 404


def test_support_pathway_endpoint(client):
    resp = client.get("/support/NG", params={"category": "otp_phishing"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["country_name"] == "Nigeria"
    assert body["immediate_steps"]
    assert body["channels"]
    assert body["data_note"]
    assert {c["kind"] for c in body["channels"]} >= {"wallet", "regulator", "police"}


def test_support_pathway_rejects_an_unsupported_country(client):
    assert client.get("/support/FR").status_code == 404


def test_reference_endpoints(client):
    countries = client.get("/reference/countries")
    assert countries.status_code == 200
    assert len(countries.json()) == 7

    one = client.get("/reference/countries/KE")
    assert one.status_code == 200
    assert one.json()["region_label"] == "Region"
    assert "M-PESA" in one.json()["providers"]

    assert client.get("/reference/countries/FR").status_code == 404

    categories = client.get("/reference/categories")
    assert categories.status_code == 200
    keys = {c["key"] for c in categories.json()}
    assert "mobile_money_reversal" in keys
    assert all(c["first_action"] for c in categories.json())


def test_sentinel_analyze_endpoint(client):
    with open(SAMPLE_CSV, "rb") as f:
        resp = client.post("/sentinel/analyze", files={"file": ("transactions_sample.csv", f, "text/csv")})
    assert resp.status_code == 200
    body = resp.json()
    assert body["n_transactions"] > 0
    assert body["n_flagged"] > 0


def test_sentinel_jobs_endpoint_lists_past_runs(client):
    with open(SAMPLE_CSV, "rb") as f:
        client.post(
            "/sentinel/analyze",
            files={"file": ("transactions_sample.csv", f, "text/csv")},
            data={"country": "KE"},
        )

    resp = client.get("/sentinel/jobs")
    assert resp.status_code == 200
    jobs = resp.json()
    assert len(jobs) == 1
    assert jobs[0]["filename"] == "transactions_sample.csv"
    assert jobs[0]["country"] == "KE"
    assert jobs[0]["n_transactions"] > 0
