"""Shared policy for the private Datasette SQLite admin.

Pure Python/SQLite so it can be tested without Datasette or Podman.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sqlite3
import threading
import time
from pathlib import Path

BASE = Path(__file__).resolve().parent
DATA = json.loads((BASE / "protected_tables.json").read_text(encoding="utf-8"))

APP_ONLY = set(DATA["app_only"])
AUTH = set(DATA["auth"])
AUDIT = set(DATA["audit"])
TECHNICAL = set(DATA["technical"])
IMMUTABLE = set(DATA["immutable"])
PROTECTED = APP_ONLY | AUTH | AUDIT | TECHNICAL | IMMUTABLE
BUSINESS = set(DATA["business"])

SENSITIVE_COLUMNS = {
    ("owner", "password"),
    ("owner", "secret"),
    ("sessions", "hash"),
    ("sessions", "csrf"),
    ("challenges", "hash"),
    ("recovery", "hash"),
    ("bootstrap", "hash"),
}

DENIED_ACTIONS = {
    sqlite3.SQLITE_ATTACH,
    sqlite3.SQLITE_DETACH,
    sqlite3.SQLITE_ALTER_TABLE,
    sqlite3.SQLITE_CREATE_INDEX,
    sqlite3.SQLITE_CREATE_TABLE,
    sqlite3.SQLITE_CREATE_TEMP_INDEX,
    sqlite3.SQLITE_CREATE_TEMP_TABLE,
    sqlite3.SQLITE_CREATE_TEMP_TRIGGER,
    sqlite3.SQLITE_CREATE_TEMP_VIEW,
    sqlite3.SQLITE_CREATE_TRIGGER,
    sqlite3.SQLITE_CREATE_VIEW,
    sqlite3.SQLITE_DROP_INDEX,
    sqlite3.SQLITE_DROP_TABLE,
    sqlite3.SQLITE_DROP_TEMP_INDEX,
    sqlite3.SQLITE_DROP_TEMP_TABLE,
    sqlite3.SQLITE_DROP_TEMP_TRIGGER,
    sqlite3.SQLITE_DROP_TEMP_VIEW,
    sqlite3.SQLITE_DROP_TRIGGER,
    sqlite3.SQLITE_DROP_VIEW,
    sqlite3.SQLITE_REINDEX,
    sqlite3.SQLITE_ANALYZE,
}
WRITE_ACTIONS = {
    sqlite3.SQLITE_INSERT,
    sqlite3.SQLITE_UPDATE,
    sqlite3.SQLITE_DELETE,
}

DANGEROUS_PRAGMAS = {
    "journal_mode",
    "wal_checkpoint",
    "locking_mode",
    "synchronous",
    "writable_schema",
    "defer_foreign_keys",
    "ignore_check_constraints",
    "trusted_schema",
    "read_uncommitted",
    "reverse_unordered_selects",
    "legacy_alter_table",
    "cell_size_check",
    "checkpoint_fullfsync",
    "fullfsync",
    "journal_size_limit",
    "max_page_count",
    "wal_autocheckpoint",
    "mmap_size",
    "cache_size",
    "page_size",
    "auto_vacuum",
    "secure_delete",
    "temp_store",
}
SAFE_PRAGMAS = {
    "application_id",
    "busy_timeout",
    "collation_list",
    "compile_options",
    "database_list",
    "foreign_key_check",
    "foreign_key_list",
    "foreign_keys",
    "function_list",
    "index_info",
    "index_list",
    "index_xinfo",
    "integrity_check",
    "journal_mode",
    "module_list",
    "pragma_list",
    "query_only",
    "recursive_triggers",
    "schema_version",
    "synchronous",
    "table_info",
    "table_xinfo",
    "user_version",
}
DANGEROUS_FUNCTIONS = {
    "load_extension",
    "readfile",
    "writefile",
    "edit",
    "fts3_tokenizer",
}

_lock = threading.Lock()
_actor = os.environ.get("VPS_ADMIN_ACTOR", "owner")
_session = os.environ.get("VPS_ADMIN_SESSION", "unknown")


def maintenance_enabled() -> bool:
    return os.environ.get("VPS_ADMIN_MAINTENANCE") == "1"


def normalize_sql(sql: str) -> str:
    sql = re.sub(r"'(?:''|[^'])*'", "?", sql)
    sql = re.sub(r"\b\d+(?:\.\d+)?\b", "?", sql)
    return re.sub(r"\s+", " ", sql).strip()


def log_write(database: str, sql: str, path: str | None = None) -> None:
    operation = sql.lstrip().split(None, 1)[0].upper() if sql.strip() else ""
    if operation not in {"INSERT", "UPDATE", "DELETE", "REPLACE"}:
        return
    destination = path or os.environ.get("VPS_ADMIN_AUDIT_LOG")
    if not destination:
        raise RuntimeError("VPS_ADMIN_AUDIT_LOG is required")
    record = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "actor": _actor,
        "session": _session,
        "db": database,
        "op": operation,
        "sha256": hashlib.sha256(sql.encode("utf-8")).hexdigest(),
        "sql": normalize_sql(sql),
    }
    with _lock:
        with open(destination, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, sort_keys=True) + "\n")


def make_authorizer(maintenance: bool):
    def authorizer(action, arg1, arg2, dbname, trigger):
        if action in DENIED_ACTIONS:
            return sqlite3.SQLITE_DENY
        if action in WRITE_ACTIONS:
            table = str(arg1).lower()
            if table in APP_ONLY:
                return sqlite3.SQLITE_DENY
            if table in AUDIT and action in {
                sqlite3.SQLITE_UPDATE,
                sqlite3.SQLITE_DELETE,
            }:
                return sqlite3.SQLITE_DENY
            if table in AUDIT and not maintenance and trigger is None:
                return sqlite3.SQLITE_DENY
            if table in PROTECTED and not maintenance and trigger is None:
                return sqlite3.SQLITE_DENY
        if action == sqlite3.SQLITE_PRAGMA:
            name = str(arg1).lower()
            if arg2 in (None, ""):
                return (
                    sqlite3.SQLITE_OK
                    if name in SAFE_PRAGMAS
                    else sqlite3.SQLITE_DENY
                )
            if name in {"foreign_keys", "recursive_triggers"}:
                return (
                    sqlite3.SQLITE_OK
                    if arg2 in (1, "1", "on", "ON", True)
                    else sqlite3.SQLITE_DENY
                )
            if name == "busy_timeout":
                return sqlite3.SQLITE_OK
            if name == "synchronous":
                return (
                    sqlite3.SQLITE_OK
                    if arg2 in (2, "2", "FULL", "full")
                    else sqlite3.SQLITE_DENY
                )
            if name in DANGEROUS_PRAGMAS:
                return sqlite3.SQLITE_DENY
            return sqlite3.SQLITE_OK
        if action == sqlite3.SQLITE_FUNCTION and str(arg2).lower() in DANGEROUS_FUNCTIONS:
            return sqlite3.SQLITE_DENY
        return sqlite3.SQLITE_OK

    return authorizer


def install(
    conn: sqlite3.Connection,
    database: str,
    *,
    maintenance: bool | None = None,
    audit_path: str | None = None,
) -> None:
    maintenance = maintenance_enabled() if maintenance is None else maintenance
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA recursive_triggers=ON")
    conn.execute("PRAGMA busy_timeout=3000")
    conn.execute("PRAGMA synchronous=FULL")
    conn.set_authorizer(make_authorizer(maintenance))
    conn.set_trace_callback(lambda sql: log_write(database, sql, audit_path))


def is_sensitive(table: str, column: str) -> bool:
    return (str(table).lower(), str(column).lower()) in SENSITIVE_COLUMNS


def masked(value):
    return "••••" if value is not None else value
