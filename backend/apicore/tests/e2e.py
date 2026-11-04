import json
from urllib.error import HTTPError
from urllib.request import Request, urlopen

BASE_URL = "http://127.0.0.1:65000"


def call(method, path, data=None, token=None, expected=200):
    body = json.dumps(data).encode("utf-8") if data is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = Request(BASE_URL + path, data=body, headers=headers, method=method)
    try:
        with urlopen(request, timeout=10) as response:
            payload = json.load(response)
            status = response.status
    except HTTPError as error:
        payload = json.load(error)
        status = error.code
    if status != expected:
        raise AssertionError(f"{method} {path}: expected {expected}, got {status}: {payload}")
    return payload


call("GET", "/healthcheck")
call("GET", "/api/v1/profile", expected=401)

registration = call(
    "POST",
    "/api/v1/auth/register",
    {
        "name": "Ada",
        "lastname1": "Integración",
        "lastname2": "Sintética",
        "date_b": "1995-05-10",
        "phone": "0000000020",
        "emer_phone": "0000000021",
        "mail": "api-e2e@moodsitto.invalid",
        "passw": "SyntheticPass-123",
    },
    expected=201,
)
token = registration["data"]["token"]

login = call(
    "POST",
    "/api/v1/auth/login",
    {"mail": "api-e2e@moodsitto.invalid", "password": "SyntheticPass-123"},
)
token = login["data"]["token"]

profile = call("GET", "/api/v1/profile", token=token)
assert profile["data"]["mail"] == "api-e2e@moodsitto.invalid"

catalogs = call("GET", "/api/v1/catalogs")["data"]
emotions = call("GET", "/api/v1/emotions/catalog")["data"]
assert catalogs["professionals"] and emotions

tracking = call(
    "POST",
    "/api/v1/emotions/tracking",
    {"id_emo_conjunto": emotions[0]["id_emocion_conjun"], "contexto": "Prueba API"},
    token=token,
    expected=201,
)
assert tracking["data"]["id_trackeo"] > 0
assert call("GET", "/api/v1/emotions/tracking", token=token)["data"]

medication = call(
    "POST",
    "/api/v1/medications",
    {
        "nombre": "Medicamento API ficticio",
        "id_compuesto": catalogs["compounds"][0]["id_compuesto"],
        "cantidad": 5,
        "id_dosis": catalogs["doses"][0]["id_dosis"],
        "id_estado": catalogs["states"][0]["id_estado"],
        "id_horario": catalogs["schedules"][0]["id_horario"],
    },
    token=token,
    expected=201,
)["data"]
assert call("GET", "/api/v1/medications", token=token)["data"]
call("PATCH", f"/api/v1/medications/{medication['id_medicamento']}", {"cantidad": 6}, token=token)

professional = catalogs["professionals"][0]
appointment = call(
    "POST",
    "/api/v1/appointments",
    {
        "id_doctor": professional["id_doctor"],
        "id_location": professional["id_location"],
        "id_area": professional["id_area"],
        "id_estado": catalogs["states"][0]["id_estado"],
        "fecha": "2030-02-20T09:30:00",
        "descripcion": "Cita sintética API",
    },
    token=token,
    expected=201,
)["data"]

reminder = call(
    "POST",
    "/api/v1/reminders",
    {
        "id_cita": appointment["id_cita"],
        "id_horario": catalogs["schedules"][0]["id_horario"],
        "contenido": "Recordatorio API ficticio",
        "id_estado": catalogs["states"][0]["id_estado"],
        "fecha": "2030-02-20T08:30:00",
    },
    token=token,
    expected=201,
)["data"]

assert call("GET", "/api/v1/appointments", token=token)["data"]
assert call("GET", "/api/v1/reminders", token=token)["data"]
call("GET", "/api/v1/diagnoses", token=token)
dashboard = call("GET", "/api/v1/dashboard", token=token)["data"]
assert set(dashboard) == {"appointments", "reminders", "emotions"}

call("DELETE", f"/api/v1/reminders/{reminder['id_recordatorio']}", token=token)
call("DELETE", f"/api/v1/appointments/{appointment['id_cita']}", token=token)
call("DELETE", f"/api/v1/medications/{medication['id_medicamento']}", token=token)

print("PASS APIcore E2E: auth, profile, catalogs, emotions, medication, appointment, reminder, diagnoses, dashboard")

