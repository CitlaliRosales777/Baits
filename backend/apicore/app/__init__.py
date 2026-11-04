import logging

from flask import Flask, jsonify, request
from pymysql.err import DataError, IntegrityError, OperationalError
from werkzeug.exceptions import HTTPException

from .api import api
from .config import load_config
from .database import Database
from .validation import ValidationError


def create_app(config_overrides: dict | None = None, database=None) -> Flask:
    overrides = config_overrides or {}
    app = Flask(__name__)
    app.config.update(load_config(testing=bool(overrides.get("TESTING"))))
    app.config.update(overrides)
    app.config.setdefault("MAX_CONTENT_LENGTH", 1_048_576)
    app.extensions["moodsitto_database"] = database or Database(app.config)
    app.register_blueprint(api, url_prefix="/api/v1")

    @app.get("/healthcheck")
    def healthcheck():
        try:
            database_ok = app.extensions["moodsitto_database"].ping()
        except OperationalError:
            database_ok = False
        status = 200 if database_ok else 503
        return jsonify({"status": "ok" if database_ok else "unavailable", "database": database_ok}), status

    @app.after_request
    def cors(response):
        origin = request.headers.get("Origin")
        if origin and origin in app.config["CORS_ORIGINS"]:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Vary"] = "Origin"
            response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, PATCH, DELETE, OPTIONS"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.errorhandler(ValidationError)
    def validation_error(error):
        return jsonify({"error": "validation_error", "message": str(error)}), 400

    @app.errorhandler(IntegrityError)
    def integrity_error(_error):
        return jsonify({"error": "conflict", "message": "The operation violates a data constraint"}), 409

    @app.errorhandler(DataError)
    def data_error(_error):
        return jsonify({"error": "validation_error", "message": "A value has an invalid type or length"}), 400

    @app.errorhandler(404)
    def not_found(_error):
        return jsonify({"error": "not_found", "message": "Resource not found"}), 404

    @app.errorhandler(HTTPException)
    def http_error(error):
        return jsonify({"error": error.name.lower().replace(" ", "_"), "message": error.description}), error.code

    @app.errorhandler(Exception)
    def unexpected_error(error):
        app.logger.exception("Unhandled API error", exc_info=error)
        return jsonify({"error": "internal_error", "message": "Unexpected server error"}), 500

    logging.basicConfig(level=logging.INFO)
    return app

