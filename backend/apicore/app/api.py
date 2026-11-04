from datetime import datetime
from functools import wraps

from flask import Blueprint, current_app, g, jsonify, request

from .security import (
    TokenError,
    hash_password,
    issue_token,
    verify_password,
    verify_token,
)
from .validation import (
    ValidationError,
    allowed_fields,
    email,
    iso_date,
    iso_datetime,
    iso_time,
    json_object,
    password,
    positive_int,
    require_fields,
)

api = Blueprint("api", __name__)


def _db():
    return current_app.extensions["moodsitto_database"]


def _ok(data=None, status=200):
    return jsonify({"status": "ok", "data": data}), status


def _not_found(resource: str):
    return jsonify({"error": "not_found", "message": f"{resource} not found"}), 404


def auth_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return jsonify({"error": "unauthorized", "message": "Bearer token required"}), 401
        try:
            g.user_id = verify_token(header[7:], current_app.config["API_SECRET"])
        except TokenError:
            return jsonify({"error": "unauthorized", "message": "Invalid or expired token"}), 401
        return view(*args, **kwargs)

    return wrapped


@api.post("/auth/register")
def register():
    data = json_object(request)
    fields = {
        "name", "lastname1", "lastname2", "date_b", "phone", "emer_phone",
        "mail", "password", "passw", "id_location",
    }
    allowed_fields(data, fields)
    require_fields(data, {"name", "lastname1", "date_b", "phone", "mail"})
    raw_password = data.get("password", data.get("passw"))
    if not raw_password:
        raise ValidationError("Missing required field: password")

    result = _db().execute(
        """
        INSERT INTO users
            (name, lastname1, lastname2, date_b, phone, emer_phone, mail, passw, id_location)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            str(data["name"]).strip(),
            str(data["lastname1"]).strip(),
            str(data.get("lastname2") or "").strip() or None,
            iso_date(data["date_b"]),
            str(data["phone"]).strip(),
            str(data.get("emer_phone") or "").strip() or None,
            email(data["mail"]),
            hash_password(password(raw_password)),
            positive_int(data["id_location"], "id_location") if data.get("id_location") else None,
        ),
    )
    token = issue_token(
        result["lastrowid"], current_app.config["API_SECRET"], current_app.config["TOKEN_TTL_SECONDS"]
    )
    return _ok({"id_user": result["lastrowid"], "token": token}, 201)


@api.post("/auth/login")
def login():
    data = json_object(request)
    allowed_fields(data, {"mail", "password", "passw"})
    raw_password = data.get("password", data.get("passw"))
    if not data.get("mail") or not raw_password:
        raise ValidationError("mail and password are required")
    user = _db().fetch_one(
        "SELECT id_user, mail, passw FROM users WHERE mail = %s",
        (email(data["mail"]),),
    )
    if not user or not verify_password(str(raw_password), user["passw"]):
        return jsonify({"error": "unauthorized", "message": "Invalid credentials"}), 401
    token = issue_token(
        user["id_user"], current_app.config["API_SECRET"], current_app.config["TOKEN_TTL_SECONDS"]
    )
    return _ok({"id_user": user["id_user"], "token": token})


@api.get("/profile")
@auth_required
def get_profile():
    profile = _db().fetch_one(
        """
        SELECT u.id_user, u.name, u.lastname1, u.lastname2, u.date_b, u.phone,
               u.emer_phone, u.mail, u.id_location, l.calle, l.colonia,
               l.num_ext, l.num_int, l.cp, l.descripcion AS location_description
        FROM users u
        LEFT JOIN location l ON l.id_location = u.id_location
        WHERE u.id_user = %s
        """,
        (g.user_id,),
    )
    return _ok(profile) if profile else _not_found("Profile")


@api.patch("/profile")
@auth_required
def update_profile():
    data = json_object(request)
    mapping = {
        "name": "name", "lastname1": "lastname1", "lastname2": "lastname2",
        "date_b": "date_b", "phone": "phone", "emer_phone": "emer_phone",
        "mail": "mail", "id_location": "id_location",
    }
    allowed_fields(data, set(mapping))
    if not data:
        raise ValidationError("At least one profile field is required")
    values = dict(data)
    if "date_b" in values:
        values["date_b"] = iso_date(values["date_b"])
    if "mail" in values:
        values["mail"] = email(values["mail"])
    if "id_location" in values and values["id_location"] is not None:
        values["id_location"] = positive_int(values["id_location"], "id_location")
    assignments = ", ".join(f"{mapping[key]} = %s" for key in values)
    result = _db().execute(
        f"UPDATE users SET {assignments} WHERE id_user = %s",
        tuple(values.values()) + (g.user_id,),
    )
    return _ok({"updated": result["rowcount"]})


@api.get("/catalogs")
def catalogs():
    return _ok({
        "states": _db().fetch_all("SELECT id_estado, estado, descripcion FROM estado ORDER BY id_estado"),
        "areas": _db().fetch_all("SELECT id_area, nombre_area, descripcion FROM area ORDER BY nombre_area"),
        "specialties": _db().fetch_all(
            "SELECT id_especialidad, especialidad, descripcion FROM especialidad ORDER BY especialidad"
        ),
        "compounds": _db().fetch_all(
            "SELECT id_compuesto, compuesto, via_admin, descripcion FROM compuesto ORDER BY compuesto"
        ),
        "doses": _db().fetch_all("SELECT id_dosis, dosis, descripcion FROM dosis ORDER BY id_dosis"),
        "schedules": _db().fetch_all(
            "SELECT id_horario, horario, descripcion FROM horarios ORDER BY horario"
        ),
        "professionals": _db().fetch_all(
            """
            SELECT d.id_doctor, d.nombre, d.apellido_p, d.id_area,
                   a.nombre_area, d.id_especialidad, e.especialidad,
                   d.id_location, l.calle, l.colonia, l.num_ext, l.num_int, l.cp
            FROM doctors d
            JOIN area a ON a.id_area = d.id_area
            JOIN especialidad e ON e.id_especialidad = d.id_especialidad
            LEFT JOIN location l ON l.id_location = d.id_location
            ORDER BY d.apellido_p, d.nombre
            """
        ),
    })


@api.get("/emotions/catalog")
def emotion_catalog():
    rows = _db().fetch_all(
        """
        SELECT eco.id_emocion_conjun, ec.id_emo_cen, ec.nombre AS central,
               em.id_emo_media, em.nombre AS media,
               ee.id_emo_espe, ee.nombre AS specific_emotion,
               i.valor AS intensity, i.color
        FROM emocion_conjunto eco
        JOIN emocion_central ec ON ec.id_emo_cen = eco.id_emo_cen
        JOIN emocion_media em ON em.id_emo_media = eco.id_emo_media
        JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
        JOIN intensidad i ON i.id_intensidad = ee.id_intensidad
        ORDER BY ec.nombre, em.nombre, ee.nombre
        """
    )
    return _ok(rows)


@api.post("/emotions/tracking")
@auth_required
def create_emotion_tracking():
    data = json_object(request)
    allowed_fields(data, {"id_emo_conjunto", "fecha", "hora", "contexto"})
    require_fields(data, {"id_emo_conjunto"})
    now = datetime.now()
    result = _db().execute(
        """
        INSERT INTO trackeo_emo (fecha, hora, contexto, id_user, id_emo_conjunto)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            iso_date(data["fecha"]) if data.get("fecha") else now.date().isoformat(),
            iso_time(data["hora"]) if data.get("hora") else now.time().replace(microsecond=0).isoformat(),
            data.get("contexto"),
            g.user_id,
            positive_int(data["id_emo_conjunto"], "id_emo_conjunto"),
        ),
    )
    return _ok({"id_trackeo": result["lastrowid"]}, 201)


@api.get("/emotions/tracking")
@auth_required
def list_emotion_tracking():
    date_from = iso_date(request.args["date_from"]) if request.args.get("date_from") else "1900-01-01"
    date_to = iso_date(request.args["date_to"]) if request.args.get("date_to") else "2999-12-31"
    limit = min(positive_int(request.args.get("limit", 50), "limit"), 100)
    rows = _db().fetch_all(
        """
        SELECT te.id_trackeo, te.fecha, te.hora, te.contexto,
               ec.nombre AS central, em.nombre AS media, ee.nombre AS specific_emotion,
               i.valor AS intensity, i.color
        FROM trackeo_emo te
        JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
        JOIN emocion_central ec ON ec.id_emo_cen = eco.id_emo_cen
        JOIN emocion_media em ON em.id_emo_media = eco.id_emo_media
        JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
        JOIN intensidad i ON i.id_intensidad = ee.id_intensidad
        WHERE te.id_user = %s AND te.fecha BETWEEN %s AND %s
        ORDER BY te.fecha DESC, te.hora DESC
        LIMIT %s
        """,
        (g.user_id, date_from, date_to, limit),
    )
    return _ok(rows)


MEDICATION_FIELDS = {
    "nombre": "nombre", "id_compuesto": "id_compuesto", "cantidad": "cantidad",
    "id_dosis": "id_dosis", "id_estado": "id_estado", "recomendaciones": "recomendaciones",
    "advertencias": "advertencias", "tratamiento": "tratamiento", "id_horario": "id_horario",
}


@api.get("/medications")
@auth_required
def list_medications():
    return _ok(_db().fetch_all(
        """
        SELECT m.id_medicamento, m.nombre, m.cantidad, m.recomendaciones,
               m.advertencias, m.tratamiento, m.id_compuesto, c.compuesto,
               c.via_admin, m.id_dosis, d.dosis, m.id_estado, e.estado,
               m.id_horario, h.horario
        FROM medicamento m
        JOIN compuesto c ON c.id_compuesto = m.id_compuesto
        JOIN dosis d ON d.id_dosis = m.id_dosis
        JOIN estado e ON e.id_estado = m.id_estado
        JOIN horarios h ON h.id_horario = m.id_horario
        WHERE m.id_user = %s ORDER BY m.nombre
        """,
        (g.user_id,),
    ))


@api.post("/medications")
@auth_required
def create_medication():
    data = json_object(request)
    allowed_fields(data, set(MEDICATION_FIELDS))
    require_fields(data, {"nombre", "id_compuesto", "cantidad", "id_dosis", "id_estado", "id_horario"})
    result = _db().execute(
        """
        INSERT INTO medicamento
          (nombre, id_compuesto, cantidad, id_dosis, id_estado, recomendaciones,
           advertencias, tratamiento, id_horario, id_user)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            data["nombre"], positive_int(data["id_compuesto"], "id_compuesto"),
            positive_int(data["cantidad"], "cantidad"), positive_int(data["id_dosis"], "id_dosis"),
            positive_int(data["id_estado"], "id_estado"), data.get("recomendaciones"),
            data.get("advertencias"), data.get("tratamiento"),
            positive_int(data["id_horario"], "id_horario"), g.user_id,
        ),
    )
    return _ok({"id_medicamento": result["lastrowid"]}, 201)


def _patch_owned(
    table: str,
    id_column: str,
    resource_id: int,
    mapping: dict,
    resource_name: str,
    data: dict | None = None,
):
    data = json_object(request) if data is None else data
    allowed_fields(data, set(mapping))
    if not data:
        raise ValidationError("At least one field is required")
    assignments = ", ".join(f"{mapping[key]} = %s" for key in data)
    result = _db().execute(
        f"UPDATE {table} SET {assignments} WHERE {id_column} = %s AND id_user = %s",
        tuple(data.values()) + (resource_id, g.user_id),
    )
    return _ok({"updated": 1}) if result["rowcount"] else _not_found(resource_name)


@api.patch("/medications/<int:resource_id>")
@auth_required
def update_medication(resource_id):
    return _patch_owned("medicamento", "id_medicamento", resource_id, MEDICATION_FIELDS, "Medication")


@api.delete("/medications/<int:resource_id>")
@auth_required
def delete_medication(resource_id):
    result = _db().execute(
        "DELETE FROM medicamento WHERE id_medicamento = %s AND id_user = %s",
        (resource_id, g.user_id),
    )
    return _ok({"deleted": 1}) if result["rowcount"] else _not_found("Medication")


APPOINTMENT_FIELDS = {
    "id_doctor": "id_doctor", "id_location": "id_location", "id_area": "id_area",
    "id_estado": "id_estado", "fecha": "fecha", "descripcion": "descripcion",
}


@api.get("/appointments")
@auth_required
def list_appointments():
    return _ok(_db().fetch_all(
        """
        SELECT c.id_cita, c.fecha, c.descripcion, c.id_doctor,
               CONCAT(d.nombre, ' ', d.apellido_p) AS doctor, c.id_location,
               c.id_area, a.nombre_area, c.id_estado, e.estado
        FROM citas_medicas c
        JOIN doctors d ON d.id_doctor = c.id_doctor
        JOIN area a ON a.id_area = c.id_area
        JOIN estado e ON e.id_estado = c.id_estado
        WHERE c.id_user = %s ORDER BY c.fecha
        """,
        (g.user_id,),
    ))


@api.post("/appointments")
@auth_required
def create_appointment():
    data = json_object(request)
    allowed_fields(data, set(APPOINTMENT_FIELDS))
    require_fields(data, {"id_doctor", "id_location", "id_area", "id_estado", "fecha"})
    result = _db().execute(
        """
        INSERT INTO citas_medicas
          (id_doctor, id_location, id_area, id_estado, fecha, descripcion, id_user)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (
            positive_int(data["id_doctor"], "id_doctor"),
            positive_int(data["id_location"], "id_location"),
            positive_int(data["id_area"], "id_area"),
            positive_int(data["id_estado"], "id_estado"),
            iso_datetime(data["fecha"]), data.get("descripcion"), g.user_id,
        ),
    )
    return _ok({"id_cita": result["lastrowid"]}, 201)


@api.patch("/appointments/<int:resource_id>")
@auth_required
def update_appointment(resource_id):
    data = json_object(request)
    if "fecha" in data:
        data["fecha"] = iso_datetime(data["fecha"])
    return _patch_owned(
        "citas_medicas", "id_cita", resource_id, APPOINTMENT_FIELDS, "Appointment", data
    )


@api.delete("/appointments/<int:resource_id>")
@auth_required
def delete_appointment(resource_id):
    result = _db().execute(
        "DELETE FROM citas_medicas WHERE id_cita = %s AND id_user = %s",
        (resource_id, g.user_id),
    )
    return _ok({"deleted": 1}) if result["rowcount"] else _not_found("Appointment")


REMINDER_FIELDS = {
    "id_cita": "id_cita", "id_horario": "id_horario", "contenido": "contenido",
    "id_estado": "id_estado", "fecha": "fecha",
}


def _validate_appointment_owner(appointment_id):
    if appointment_id is None:
        return
    owned = _db().fetch_one(
        "SELECT id_cita FROM citas_medicas WHERE id_cita = %s AND id_user = %s",
        (positive_int(appointment_id, "id_cita"), g.user_id),
    )
    if not owned:
        raise ValidationError("id_cita does not belong to the authenticated user")


@api.get("/reminders")
@auth_required
def list_reminders():
    return _ok(_db().fetch_all(
        """
        SELECT r.id_recordatorio, r.id_cita, r.id_horario, h.horario,
               r.contenido, r.id_estado, e.estado, r.fecha
        FROM recordatorios r
        JOIN horarios h ON h.id_horario = r.id_horario
        JOIN estado e ON e.id_estado = r.id_estado
        WHERE r.id_user = %s ORDER BY r.fecha
        """,
        (g.user_id,),
    ))


@api.post("/reminders")
@auth_required
def create_reminder():
    data = json_object(request)
    allowed_fields(data, set(REMINDER_FIELDS))
    require_fields(data, {"id_horario", "contenido", "id_estado", "fecha"})
    _validate_appointment_owner(data.get("id_cita"))
    result = _db().execute(
        """
        INSERT INTO recordatorios
          (id_user, id_cita, id_horario, contenido, id_estado, fecha)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (
            g.user_id, data.get("id_cita"), positive_int(data["id_horario"], "id_horario"),
            data["contenido"], positive_int(data["id_estado"], "id_estado"),
            iso_datetime(data["fecha"]),
        ),
    )
    return _ok({"id_recordatorio": result["lastrowid"]}, 201)


@api.patch("/reminders/<int:resource_id>")
@auth_required
def update_reminder(resource_id):
    data = json_object(request)
    _validate_appointment_owner(data.get("id_cita"))
    if "fecha" in data:
        data["fecha"] = iso_datetime(data["fecha"])
    return _patch_owned(
        "recordatorios", "id_recordatorio", resource_id, REMINDER_FIELDS, "Reminder", data
    )


@api.delete("/reminders/<int:resource_id>")
@auth_required
def delete_reminder(resource_id):
    result = _db().execute(
        "DELETE FROM recordatorios WHERE id_recordatorio = %s AND id_user = %s",
        (resource_id, g.user_id),
    )
    return _ok({"deleted": 1}) if result["rowcount"] else _not_found("Reminder")


@api.get("/diagnoses")
@auth_required
def list_diagnoses():
    return _ok(_db().fetch_all(
        """
        SELECT dg.id_diagnostico, dg.nombre, dg.descripcion, dg.fecha, dg.documento,
               a.nombre_area, ec.estado_c, e.estado,
               CONCAT(d.nombre, ' ', d.apellido_p) AS doctor
        FROM diagnosticos dg
        JOIN area a ON a.id_area = dg.id_area
        JOIN estados_clinicos ec ON ec.id_estadoclini = dg.id_estadoclini
        JOIN estado e ON e.id_estado = dg.id_estado
        JOIN doctors d ON d.id_doctor = dg.id_doctor
        WHERE dg.id_user = %s ORDER BY dg.fecha DESC
        """,
        (g.user_id,),
    ))


@api.get("/dashboard")
@auth_required
def dashboard():
    appointments = _db().fetch_all(
        """
        SELECT c.id_cita, c.fecha, c.descripcion,
               CONCAT(d.nombre, ' ', d.apellido_p) AS doctor, e.estado
        FROM citas_medicas c
        JOIN doctors d ON d.id_doctor = c.id_doctor
        JOIN estado e ON e.id_estado = c.id_estado
        WHERE c.id_user = %s AND c.fecha >= NOW()
        ORDER BY c.fecha LIMIT 5
        """,
        (g.user_id,),
    )
    reminders = _db().fetch_all(
        """
        SELECT r.id_recordatorio, r.contenido, r.fecha, e.estado
        FROM recordatorios r JOIN estado e ON e.id_estado = r.id_estado
        WHERE r.id_user = %s AND r.fecha >= NOW()
        ORDER BY r.fecha LIMIT 10
        """,
        (g.user_id,),
    )
    emotions = _db().fetch_all(
        """
        SELECT te.id_trackeo, te.fecha, te.hora, ee.nombre AS emotion, i.valor AS intensity
        FROM trackeo_emo te
        JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
        JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
        JOIN intensidad i ON i.id_intensidad = ee.id_intensidad
        WHERE te.id_user = %s
        ORDER BY te.fecha DESC, te.hora DESC LIMIT 10
        """,
        (g.user_id,),
    )
    return _ok({"appointments": appointments, "reminders": reminders, "emotions": emotions})

