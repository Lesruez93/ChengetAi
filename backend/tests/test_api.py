from pathlib import Path

SAMPLE_CSV = Path(__file__).resolve().parents[2] / "sample_data" / "transactions_sample.csv"


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_classify_endpoint(client):
    resp = client.post("/classify", json={"text": "Pay $15 registration fee to secure your remote job slot."})
    assert resp.status_code == 200
    body = resp.json()
    assert body["verdict"] in {"scam", "suspicious", "safe"}
    assert body["strategy_used"] == "baseline"


def test_report_then_lookup_number(client):
    report_resp = client.post("/reports", json={
        "msisdn": "0712223333", "category": "ecocash_reversal", "province": "Harare",
        "message_excerpt": "reverse the money please",
    })
    assert report_resp.status_code == 200
    assert report_resp.json()["status"] == "recorded"

    lookup_resp = client.get("/numbers/0712223333")
    assert lookup_resp.status_code == 200
    assert lookup_resp.json()["report_count"] == 1


def test_lookup_invalid_number_returns_422(client):
    resp = client.get("/numbers/123")
    assert resp.status_code == 422


def test_list_numbers_endpoint_ranks_by_report_count(client):
    resp = client.get("/numbers")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) > 0
    counts = [n["report_count"] for n in body]
    assert counts == sorted(counts, reverse=True)


def test_list_reports_endpoint_supports_filtering(client):
    resp = client.get("/reports")
    assert resp.status_code == 200
    assert len(resp.json()) > 0

    filtered = client.get("/reports", params={"category": "ecocash_reversal"})
    assert filtered.status_code == 200
    assert all(r["category"] == "ecocash_reversal" for r in filtered.json())


def test_feed_and_trending_endpoints(client):
    assert client.get("/feed").status_code == 200
    trending_resp = client.get("/feed/trending")
    assert trending_resp.status_code == 200
    assert "hotspots" in trending_resp.json()


def test_sentinel_analyze_endpoint(client):
    with open(SAMPLE_CSV, "rb") as f:
        resp = client.post("/sentinel/analyze", files={"file": ("transactions_sample.csv", f, "text/csv")})
    assert resp.status_code == 200
    body = resp.json()
    assert body["n_transactions"] > 0
    assert body["n_flagged"] > 0


def test_sentinel_jobs_endpoint_lists_past_runs(client):
    with open(SAMPLE_CSV, "rb") as f:
        client.post("/sentinel/analyze", files={"file": ("transactions_sample.csv", f, "text/csv")})

    resp = client.get("/sentinel/jobs")
    assert resp.status_code == 200
    jobs = resp.json()
    assert len(jobs) == 1
    assert jobs[0]["filename"] == "transactions_sample.csv"
    assert jobs[0]["n_transactions"] > 0
