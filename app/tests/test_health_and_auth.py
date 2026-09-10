def test_healthz(client):
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_dashboard_requires_login(client):
    response = client.get("/", follow_redirects=False)
    assert response.status_code == 302
    assert "/login" in response.headers["Location"]


def test_api_requires_login_returns_json_401(client):
    response = client.get("/api/files")
    assert response.status_code == 401
    assert response.get_json() == {"error": "No autenticado"}
