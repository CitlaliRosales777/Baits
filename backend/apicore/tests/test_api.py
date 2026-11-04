from app import create_app
from app.security import hash_password


class FakeDatabase:
    def __init__(self):
        self.executions = []
        self.rows = {}

    def ping(self):
        return True

    def execute(self, sql, params=()):
        self.executions.append((sql, params))
        return {"rowcount": 1, "lastrowid": 17}

    def fetch_one(self, sql, params=()):
        if "SELECT id_user, mail, passw" in sql:
            return self.rows.get("login")
        if "FROM users u" in sql:
            return self.rows.get("profile")
        return None

    def fetch_all(self, _sql, _params=()):
        return []


def make_client(database):
    app = create_app(
        {
            "TESTING": True,
            "API_SECRET": "s" * 32,
            "TOKEN_TTL_SECONDS": 60,
            "CORS_ORIGINS": {"http://localhost:5500"},
        },
        database=database,
    )
    return app.test_client()


def test_healthcheck_reports_database_status():
    response = make_client(FakeDatabase()).get("/healthcheck")

    assert response.status_code == 200
    assert response.get_json() == {"status": "ok", "database": True}


def test_registration_hashes_password_and_accepts_frontend_field_name():
    database = FakeDatabase()
    client = make_client(database)

    response = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Ada",
            "lastname1": "Prueba",
            "date_b": "1995-05-10",
            "phone": "0000000001",
            "mail": "ADA@EXAMPLE.INVALID",
            "passw": "SyntheticPass-123",
        },
    )

    assert response.status_code == 201
    assert response.get_json()["data"]["id_user"] == 17
    inserted = database.executions[0][1]
    assert inserted[6] == "ada@example.invalid"
    assert inserted[7] != "SyntheticPass-123"


def test_login_returns_token_but_never_hash():
    database = FakeDatabase()
    database.rows["login"] = {
        "id_user": 17,
        "mail": "ada@example.invalid",
        "passw": hash_password("SyntheticPass-123"),
    }
    client = make_client(database)

    response = client.post(
        "/api/v1/auth/login",
        json={"mail": "ada@example.invalid", "password": "SyntheticPass-123"},
    )

    body = response.get_json()
    assert response.status_code == 200
    assert body["data"]["id_user"] == 17
    assert "." in body["data"]["token"]
    assert "passw" not in body["data"]


def test_profile_requires_bearer_token():
    response = make_client(FakeDatabase()).get("/api/v1/profile")

    assert response.status_code == 401
    assert response.get_json()["error"] == "unauthorized"

