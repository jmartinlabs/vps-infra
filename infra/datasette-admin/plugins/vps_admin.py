import sqlite3
import sys
from pathlib import Path

from datasette import hookimpl
from datasette.database import Database as _DatasetteDatabase
from datasette.utils.asgi import Response

sys.path.insert(0, str(Path(__file__).resolve().parent))
import policy


def _is_app_database(database) -> bool:
    return not database.name.startswith("_")


class _GuardedCursor:
    def __init__(self, cursor: sqlite3.Cursor):
        self._cursor = cursor

    def __getattr__(self, name):
        return getattr(self._cursor, name)

    def execute(self, sql, parameters=()):
        policy.validate_connection_sql(sql)
        return self._cursor.execute(sql, parameters)

    def executemany(self, sql, parameters):
        policy.validate_connection_sql(sql)
        return self._cursor.executemany(sql, parameters)

    def executescript(self, sql):
        raise ValueError("multi-statement writes are not supported")


class _GuardedConnection:
    """Connection proxy used by callback-style Datasette writes."""

    def __init__(self, connection: sqlite3.Connection):
        object.__setattr__(self, "_connection", connection)

    def __getattr__(self, name):
        return getattr(object.__getattribute__(self, "_connection"), name)

    def __setattr__(self, name, value):
        setattr(object.__getattribute__(self, "_connection"), name, value)

    def __enter__(self):
        self._connection.__enter__()
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return self._connection.__exit__(exc_type, exc_value, traceback)

    def execute(self, sql, parameters=()):
        policy.validate_connection_sql(sql)
        return self._connection.execute(sql, parameters)

    def executemany(self, sql, parameters):
        policy.validate_connection_sql(sql)
        return self._connection.executemany(sql, parameters)

    def executescript(self, sql):
        raise ValueError("multi-statement writes are not supported")

    def cursor(self):
        return _GuardedCursor(self._connection.cursor())


_ORIGINAL_CONNECT = _DatasetteDatabase.connect
_ORIGINAL_EXECUTE = _DatasetteDatabase.execute
_ORIGINAL_EXECUTE_WRITE = _DatasetteDatabase.execute_write
_ORIGINAL_EXECUTE_WRITE_MANY = _DatasetteDatabase.execute_write_many
_ORIGINAL_EXECUTE_WRITE_SCRIPT = _DatasetteDatabase.execute_write_script
_ORIGINAL_EXECUTE_WRITE_FN = _DatasetteDatabase.execute_write_fn


def _prepared_connect(self, write=False):
    conn = _ORIGINAL_CONNECT(self, write=write)
    # Datasette normally prepares pooled connections in _execute_fn, but
    # plugins and custom routes can call Database.connect() directly.
    if _is_app_database(self):
        self.ds._prepare_connection(conn, self.name)
    return conn


async def _guarded_execute(self, sql, *args, **kwargs):
    if _is_app_database(self):
        policy.validate_read_sql(sql)
    return await _ORIGINAL_EXECUTE(self, sql, *args, **kwargs)


async def _guarded_execute_write(self, sql, params=None, *args, **kwargs):
    if _is_app_database(self):
        policy.validate_write_sql(sql)
    return await _ORIGINAL_EXECUTE_WRITE(self, sql, params, *args, **kwargs)


async def _guarded_execute_write_many(self, sql, params_seq, *args, **kwargs):
    if _is_app_database(self):
        policy.validate_write_sql(sql)
    return await _ORIGINAL_EXECUTE_WRITE_MANY(self, sql, params_seq, *args, **kwargs)


async def _guarded_execute_write_script(self, sql, *args, **kwargs):
    if _is_app_database(self):
        raise ValueError("multi-statement writes are not supported")
    return await _ORIGINAL_EXECUTE_WRITE_SCRIPT(self, sql, *args, **kwargs)


async def _guarded_execute_write_fn(self, fn, *args, **kwargs):
    if not _is_app_database(self):
        return await _ORIGINAL_EXECUTE_WRITE_FN(self, fn, *args, **kwargs)

    def guarded(conn, *fn_args, **fn_kwargs):
        return fn(_GuardedConnection(conn), *fn_args, **fn_kwargs)

    return await _ORIGINAL_EXECUTE_WRITE_FN(self, guarded, *args, **kwargs)


_DatasetteDatabase.connect = _prepared_connect
_DatasetteDatabase.execute = _guarded_execute
_DatasetteDatabase.execute_write = _guarded_execute_write
_DatasetteDatabase.execute_write_many = _guarded_execute_write_many
_DatasetteDatabase.execute_write_script = _guarded_execute_write_script
_DatasetteDatabase.execute_write_fn = _guarded_execute_write_fn


@hookimpl
def prepare_connection(conn, database, datasette):
    if database.startswith("_") or isinstance(conn, _GuardedConnection):
        return
    policy.install(conn, database)


@hookimpl
def render_cell(row, value, column, table, pks, database, datasette, request, column_type):
    if policy.is_sensitive(table, column):
        return policy.masked(value)
    return None


@hookimpl
def register_routes():
    return [(r"^/-/vps-admin-health$", health)]


async def health(request, datasette):
    try:
        databases = [
            database
            for database in datasette.databases.values()
            if _is_app_database(database)
        ]
        if not databases:
            raise RuntimeError("no application database")
        database = databases[0]
        conn = database.connect()
        try:
            foreign_keys = conn.execute("PRAGMA foreign_keys").fetchone()[0]
            recursive = conn.execute("PRAGMA recursive_triggers").fetchone()[0]
            maintenance = policy.maintenance_enabled()
        finally:
            conn.close()
        return Response.json(
            {
                "policy": "loaded",
                "foreign_keys": foreign_keys,
                "recursive_triggers": recursive,
                "maintenance": maintenance,
                "protected_tables": len(policy.PROTECTED),
            }
        )
    except Exception as error:
        return Response.json(
            {"policy": "error", "error": type(error).__name__},
            status=500,
        )
