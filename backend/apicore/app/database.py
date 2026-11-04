from contextlib import contextmanager
from datetime import date, datetime, time, timedelta
from decimal import Decimal

import pymysql
from pymysql.cursors import DictCursor


def _json_value(value):
    if isinstance(value, (date, datetime, time)):
        return value.isoformat()
    if isinstance(value, timedelta):
        total_seconds = int(value.total_seconds())
        hours, remainder = divmod(total_seconds, 3600)
        minutes, seconds = divmod(remainder, 60)
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
    if isinstance(value, Decimal):
        return float(value)
    return value


def _json_row(row):
    if row is None:
        return None
    return {key: _json_value(value) for key, value in row.items()}


class Database:
    def __init__(self, config: dict):
        self._config = config

    def _connect(self):
        return pymysql.connect(
            host=self._config["DB_HOST"],
            port=self._config["DB_PORT"],
            user=self._config["DB_USER"],
            password=self._config["DB_PASSWORD"],
            database=self._config["DB_NAME"],
            charset="utf8mb4",
            cursorclass=DictCursor,
            autocommit=False,
            connect_timeout=5,
            read_timeout=10,
            write_timeout=10,
        )

    @contextmanager
    def transaction(self):
        connection = self._connect()
        try:
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def fetch_one(self, sql: str, params=()):
        connection = self._connect()
        try:
            with connection.cursor() as cursor:
                cursor.execute(sql, params)
                return _json_row(cursor.fetchone())
        finally:
            connection.close()

    def fetch_all(self, sql: str, params=()):
        connection = self._connect()
        try:
            with connection.cursor() as cursor:
                cursor.execute(sql, params)
                return [_json_row(row) for row in cursor.fetchall()]
        finally:
            connection.close()

    def execute(self, sql: str, params=()):
        with self.transaction() as connection, connection.cursor() as cursor:
            cursor.execute(sql, params)
            return {"rowcount": cursor.rowcount, "lastrowid": cursor.lastrowid}

    def ping(self):
        row = self.fetch_one("SELECT 1 AS healthy")
        return bool(row and row["healthy"] == 1)

