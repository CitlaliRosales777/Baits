import os


class ConfigurationError(RuntimeError):
    pass


def _required(name: str, testing: bool) -> str:
    value = os.getenv(name, "")
    if value:
        return value
    if testing:
        return f"test-{name.lower()}"
    raise ConfigurationError(f"Missing required environment variable: {name}")


def load_config(testing: bool = False) -> dict:
    secret = _required("MOODSITTO_API_SECRET", testing)
    if not testing and len(secret) < 32:
        raise ConfigurationError("MOODSITTO_API_SECRET must contain at least 32 characters")

    return {
        "TESTING": testing,
        "DB_HOST": os.getenv("MOODSITTO_DB_HOST", "127.0.0.1"),
        "DB_PORT": int(os.getenv("MOODSITTO_DB_PORT", "3306")),
        "DB_NAME": os.getenv("MOODSITTO_DB_NAME", "moodsitto"),
        "DB_USER": _required("MOODSITTO_DB_USER", testing),
        "DB_PASSWORD": _required("MOODSITTO_DB_PASSWORD", testing),
        "API_SECRET": secret,
        "API_HOST": os.getenv("MOODSITTO_API_HOST", "127.0.0.1"),
        "API_PORT": int(os.getenv("MOODSITTO_API_PORT", "65000")),
        "TOKEN_TTL_SECONDS": int(os.getenv("MOODSITTO_TOKEN_TTL_SECONDS", "3600")),
        "CORS_ORIGINS": {
            value.strip()
            for value in os.getenv("MOODSITTO_CORS_ORIGINS", "").split(",")
            if value.strip()
        },
    }

