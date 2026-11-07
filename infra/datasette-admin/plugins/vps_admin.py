import sys
from pathlib import Path

from datasette import hookimpl
from datasette.database import Database as _DatasetteDatabase
from datasette.utils.asgi import Response

sys.path.insert(0, str(Path(__file__).resolve().parent))
import policy

_ORIGINAL_CONNECT = _DatasetteDatabase.connect
_ORIGINAL_EXECUTE_WRITE = _DatasetteDatabase.execute_write


def _prepared_connect(self, write=False):
    conn = _ORIGINAL_CONNECT(self, write=write)
    # Datasette normally prepares pooled connections in _execute_fn, but
    # plugins and custom routes can call Database.connect() directly.
    self.ds._prepare_connection(conn, self.name)
    return conn


async def _guarded_execute_write(self, sql, params=None, *args, **kwargs):
    policy.validate_write_sql(sql)
    return await _ORIGINAL_EXECUTE_WRITE(self, sql, params, *args, **kwargs)


_DatasetteDatabase.connect = _prepared_connect
_DatasetteDatabase.execute_write = _guarded_execute_write


@hookimpl
def prepare_connection(conn, database, datasette):
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
        database = next(iter(datasette.databases.values()))
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
