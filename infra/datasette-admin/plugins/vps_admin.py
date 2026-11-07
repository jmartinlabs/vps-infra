import sys
from pathlib import Path

from datasette import hookimpl
from datasette.database import Database as _DatasetteDatabase

sys.path.insert(0, str(Path(__file__).resolve().parent))
import policy

_ORIGINAL_CONNECT = _DatasetteDatabase.connect


def _prepared_connect(self, write=False):
    conn = _ORIGINAL_CONNECT(self, write=write)
    # Datasette normally prepares pooled connections in _execute_fn, but
    # plugins and custom routes can call Database.connect() directly.
    self.ds._prepare_connection(conn, self.name)
    return conn


_DatasetteDatabase.connect = _prepared_connect


@hookimpl
def prepare_connection(conn, database, datasette):
    policy.install(conn, database)


@hookimpl
def render_cell(row, value, column, table, pks, database, datasette, request, column_type):
    if policy.is_sensitive(table, column):
        return policy.masked(value)
    return None
