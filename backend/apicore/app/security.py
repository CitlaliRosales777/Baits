import base64
import hashlib
import hmac
import json
import time

import bcrypt


class TokenError(ValueError):
    pass


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("ascii")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("ascii"))
    except (ValueError, UnicodeError):
        return False


def _encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def issue_token(user_id: int, secret: str, ttl_seconds: int, now: int | None = None) -> str:
    issued_at = int(time.time() if now is None else now)
    payload = {"sub": int(user_id), "iat": issued_at, "exp": issued_at + ttl_seconds}
    encoded = _encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signature = _encode(hmac.new(secret.encode("utf-8"), encoded.encode("ascii"), hashlib.sha256).digest())
    return f"{encoded}.{signature}"


def verify_token(token: str, secret: str, now: int | None = None) -> int:
    try:
        encoded, provided_signature = token.split(".", 1)
        expected_signature = _encode(
            hmac.new(secret.encode("utf-8"), encoded.encode("ascii"), hashlib.sha256).digest()
        )
        if not hmac.compare_digest(provided_signature, expected_signature):
            raise TokenError("invalid token")
        payload = json.loads(_decode(encoded))
        current_time = int(time.time() if now is None else now)
        if int(payload["exp"]) <= current_time:
            raise TokenError("expired token")
        return int(payload["sub"])
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        if isinstance(error, TokenError):
            raise
        raise TokenError("invalid token") from error

