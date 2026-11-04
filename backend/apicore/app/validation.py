from datetime import date, datetime, time
from re import fullmatch


class ValidationError(ValueError):
    pass


def json_object(request):
    value = request.get_json(silent=True)
    if not isinstance(value, dict):
        raise ValidationError("Request body must be a JSON object")
    return value


def require_fields(data: dict, fields: set[str]):
    missing = sorted(field for field in fields if data.get(field) in (None, ""))
    if missing:
        raise ValidationError(f"Missing required fields: {', '.join(missing)}")


def allowed_fields(data: dict, fields: set[str]):
    unknown = sorted(set(data) - fields)
    if unknown:
        raise ValidationError(f"Unknown fields: {', '.join(unknown)}")


def email(value: str) -> str:
    normalized = value.strip().lower()
    if len(normalized) > 254 or not fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", normalized):
        raise ValidationError("Invalid email")
    return normalized


def password(value: str) -> str:
    if len(value) < 8 or len(value.encode("utf-8")) > 72:
        raise ValidationError("Password must contain at least 8 characters and at most 72 UTF-8 bytes")
    return value


def iso_date(value: str) -> str:
    try:
        return date.fromisoformat(value).isoformat()
    except (TypeError, ValueError) as error:
        raise ValidationError("Invalid date; expected YYYY-MM-DD") from error


def iso_datetime(value: str) -> str:
    try:
        parsed = datetime.fromisoformat(value)
        return parsed.replace(microsecond=0).isoformat(sep=" ")
    except (TypeError, ValueError) as error:
        raise ValidationError("Invalid datetime; expected ISO 8601") from error


def iso_time(value: str) -> str:
    try:
        return time.fromisoformat(value).replace(microsecond=0).isoformat()
    except (TypeError, ValueError) as error:
        raise ValidationError("Invalid time; expected HH:MM[:SS]") from error


def positive_int(value, field: str) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError) as error:
        raise ValidationError(f"{field} must be an integer") from error
    if parsed <= 0:
        raise ValidationError(f"{field} must be positive")
    return parsed

