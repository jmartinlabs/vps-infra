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
    sqlite3.SQLITE_CREATE_VTABLE,
    sqlite3.SQLITE_DROP_VTABLE,
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


def scan_sql(sql: str, *, mask_literals: bool = True) -> str:
    """Remove comments and optionally replace string literals with ``?``.

    The scan is string-aware, so ``--`` or ``/* */`` inside a literal does not
    hide the rest of the statement. Double-quoted, backtick and bracket
    identifiers are preserved so table references such as ``"audit"`` remain
    visible to the policy.
    """
    output: list[str] = []
    index = 0
    length = len(sql)
    while index < length:
        char = sql[index]
        following = sql[index + 1] if index + 1 < length else ""
        if char == "'":
            start = index
            index += 1
            while index < length:
                if sql[index] == "'":
                    if index + 1 < length and sql[index + 1] == "'":
                        index += 2
                        continue
                    index += 1
                    break
                index += 1
            output.append("?" if mask_literals else sql[start:index])
        elif char in {'"', "`"}:
            quote = char
            end = index + 1
            while end < length:
                if sql[end] == quote:
                    if end + 1 < length and sql[end + 1] == quote:
                        end += 2
                        continue
                    end += 1
                    break
                end += 1
            output.append(sql[index:end])
            index = end
        elif char == "[":
            end = sql.find("]", index + 1)
            if end == -1:
                output.append(sql[index:])
                break
            output.append(sql[index : end + 1])
            index = end + 1
        elif char == "-" and following == "-":
            end = sql.find("\n", index + 2)
            index = length if end == -1 else end
        elif char == "/" and following == "*":
            end = sql.find("*/", index + 2)
            index = length if end == -1 else end + 2
        else:
            output.append(char)
            index += 1
    return "".join(output)


def strip_sql_comments(sql: str) -> str:
    return scan_sql(sql)


def normalize_sql(sql: str) -> str:
    sql = scan_sql(sql)
    # Double quotes can behave as string literals in SQLite, so mask quoted
    # identifiers and brackets as well before writing the audit record.
    sql = re.sub(r'"(?:""|[^"])*"', "?", sql)
    sql = re.sub(r"`(?:``|[^`])*`", "?", sql)
    sql = re.sub(r"\[[^\]]*\]", "?", sql)
    sql = re.sub(r"\b\d+(?:\.\d+)?\b", "?", sql)
    return re.sub(r"\s+", " ", sql).strip()


def first_keyword(sql: str) -> str:
    text = scan_sql(sql).strip()
    match = re.match(r"([A-Za-z]+)", text)
    return match.group(1).upper() if match else ""


def write_operation(sql: str) -> str | None:
    """Return the DML verb of a statement, including a CTE write."""
    text = scan_sql(sql)
    match = re.search(r"\b(INSERT|UPDATE|DELETE|REPLACE)\b", text, re.I)
    return match.group(1).upper() if match else None


def unquote_identifier(value: str) -> str:
    value = value.strip()
    if "." in value:
        value = value.rsplit(".", 1)[1].strip()
    if len(value) >= 2 and value[0] in {"'", '"', "`"} and value[-1] == value[0]:
        quote = value[0]
        return value[1:-1].replace(quote * 2, quote)
    if len(value) >= 2 and value[0] == "[" and value[-1] == "]":
        return value[1:-1]
    return value


def target_table(sql: str) -> str:
    """Return the table targeted by a top-level INSERT/UPDATE/DELETE/REPLACE."""
    text = scan_sql(sql, mask_literals=False)
    identifier = (
        r"(?:[A-Za-z_][A-Za-z0-9_$]*|\"[^\"]*\"|`[^`]*`|\[[^\]]*\]|'[^']*')"
    )
    match = re.search(
        rf"\b(?:"
        rf"INSERT(?:\s+OR\s+\w+)?\s+INTO"
        rf"|REPLACE\s+INTO"
        rf"|UPDATE(?:\s+OR\s+\w+)?"
        rf"|DELETE\s+FROM"
        rf")\s+({identifier}(?:\s*\.\s*{identifier})?)",
        text,
        re.I,
    )
    return unquote_identifier(match.group(1)).lower() if match else ""


def validate_read_sql(sql: str) -> None:
    """Reject write operations before they reach a read connection."""
    text = scan_sql(sql).strip()
    verb = first_keyword(sql)
    if not verb:
        raise ValueError("empty or unclassifiable SQL")
    if verb == "PRAGMA":
        remainder = text[len(verb) :].strip()
        if "=" in remainder:
            raise ValueError("PRAGMA writes are not allowed")
        return
    if verb not in {"SELECT", "WITH", "EXPLAIN", "VALUES"}:
        raise ValueError(f"read operation not allowed: {verb}")


def validate_write_sql(sql: str) -> None:
    """Reject SQL that the authorizer alone cannot classify safely."""
    text = scan_sql(sql).strip()
    verb = first_keyword(sql)
    if not verb:
        raise ValueError("empty or unclassifiable SQL")
    if verb in {
        "ALTER",
        "ANALYZE",
        "ATTACH",
        "BEGIN",
        "COMMIT",
        "CREATE",
        "DETACH",
        "DROP",
        "END",
        "PRAGMA",
        "REINDEX",
        "RELEASE",
        "ROLLBACK",
        "SAVEPOINT",
        "VACUUM",
    }:
        raise ValueError(f"SQL operation not allowed: {verb}")
    if verb == "WITH":
        raise ValueError("CTE writes are not supported")
    if verb not in {"INSERT", "UPDATE", "DELETE", "REPLACE", "EXPLAIN"}:
        raise ValueError(f"SQL operation not supported: {verb}")
    target = target_table(sql)
    if target in AUDIT:
        if verb in {"UPDATE", "DELETE"}:
            raise ValueError("audit tables are append-only")
        if re.search(r"\bREPLACE\b|\bon\s+conflict\b", text, re.I):
            raise ValueError("audit tables are append-only")


def validate_connection_sql(sql: str) -> None:
    """Validation for callback writes that use a raw connection.

    Allows read-only statements, transaction control and the two connection
    setup PRAGMAs. Everything else goes through the write allowlist.
    """
    text = scan_sql(sql).strip()
    verb = first_keyword(sql)
    if not verb:
        return
    if verb in {"BEGIN", "COMMIT", "END", "ROLLBACK", "SAVEPOINT", "RELEASE"}:
        return
    if verb in {"SELECT", "VALUES", "EXPLAIN"}:
        return
    if verb == "WITH":
        if write_operation(sql) is None:
            return
        raise ValueError("CTE writes are not supported")
    if verb == "PRAGMA":
        setup = re.fullmatch(
            r"PRAGMA\s+(?:foreign_keys|recursive_triggers)\s*=\s*(?:on|1)\s*;?",
            text,
            re.I,
        )
        timeout = re.fullmatch(
            r"PRAGMA\s+busy_timeout\s*=\s*\d+\s*;?", text, re.I
        )
        if setup or timeout:
            return
        if "=" not in text:
            return
        raise ValueError("PRAGMA writes are not allowed")
    validate_write_sql(sql)


def log_write(database: str, sql: str, path: str | None = None) -> None:
    operation = write_operation(sql)
    if operation is None:
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
        "sha256": hashlib.sha256(normalize_sql(sql).encode("utf-8")).hexdigest(),
        "sql": normalize_sql(sql),
    }
    backup_ref = os.environ.get("VPS_ADMIN_BACKUP_REF")
    if backup_ref:
        record["backup"] = backup_ref
    with _lock:
        with open(destination, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, sort_keys=True) + "\n")
            handle.flush()
            os.fsync(handle.fileno())


def make_authorizer(maintenance: bool):
    def authorizer(action, arg1, arg2, dbname, trigger):
        if action in DENIED_ACTIONS:
            return sqlite3.SQLITE_DENY
        if action in WRITE_ACTIONS:
            table = str(arg1).lower()
            if table in APP_ONLY:
                return sqlite3.SQLITE_DENY
            if table in AUDIT:
                if action in {sqlite3.SQLITE_UPDATE, sqlite3.SQLITE_DELETE}:
                    return sqlite3.SQLITE_DENY
                if action == sqlite3.SQLITE_INSERT:
                    if trigger is not None or maintenance:
                        return sqlite3.SQLITE_OK
                    return sqlite3.SQLITE_DENY
            if table in PROTECTED:
                if not maintenance and trigger is None:
                    return sqlite3.SQLITE_DENY
                return sqlite3.SQLITE_OK
            if table in BUSINESS:
                return sqlite3.SQLITE_OK
            return sqlite3.SQLITE_DENY
        if action == sqlite3.SQLITE_PRAGMA:
            name = str(arg1).lower()
            if name in {"schema_version", "user_version", "application_id", "query_only"}:
                return (
                    sqlite3.SQLITE_OK
                    if arg2 in (None, "")
                    else sqlite3.SQLITE_DENY
                )
            if name == "journal_mode":
                return (
                    sqlite3.SQLITE_OK
                    if arg2 in (None, "")
                    else sqlite3.SQLITE_DENY
                )
            if name in {"foreign_keys", "recursive_triggers"}:
                if arg2 in (None, ""):
                    return sqlite3.SQLITE_OK
                return (
                    sqlite3.SQLITE_OK
                    if arg2 in (1, "1", "on", "ON", True)
                    else sqlite3.SQLITE_DENY
                )
            if name == "busy_timeout":
                return sqlite3.SQLITE_OK
            if name == "synchronous":
                if arg2 in (None, ""):
                    return sqlite3.SQLITE_OK
                return (
                    sqlite3.SQLITE_OK
                    if arg2 in (2, "2", "FULL", "full")
                    else sqlite3.SQLITE_DENY
                )
            if name in DANGEROUS_PRAGMAS:
                return sqlite3.SQLITE_DENY
            return (
                sqlite3.SQLITE_OK
                if name in SAFE_PRAGMAS
                else sqlite3.SQLITE_DENY
            )
        if action == sqlite3.SQLITE_FUNCTION and str(arg2).lower() in DANGEROUS_FUNCTIONS:
            return sqlite3.SQLITE_DENY
        return sqlite3.SQLITE_OK

    return authorizer


def quote_identifier(name: str) -> str:
    return '"' + str(name).replace('"', '""') + '"'


def audit_insert_condition(conn: sqlite3.Connection, table: str) -> str:
    conditions: list[tuple[str, ...]] = []
    rows = conn.execute(f"PRAGMA table_info({quote_identifier(table)})").fetchall()
    keys = tuple(row[1] for row in rows if row[5])
    if keys:
        conditions.append(keys)
    for index in conn.execute(
        f"PRAGMA index_list({quote_identifier(table)})"
    ).fetchall():
        # (seq, name, unique, origin, partial)
        if not index[2] or index[3] == "pk":
            continue
        columns = tuple(
            column[2]
            for column in conn.execute(
                f"PRAGMA index_info({quote_identifier(index[1])})"
            ).fetchall()
            if column[2] is not None
        )
        if columns and columns not in conditions:
            conditions.append(columns)
    if not conditions:
        return "rowid = NEW.rowid"
    clauses = []
    for columns in conditions:
        equality = " AND ".join(
            f"{quote_identifier(column)} IS NEW.{quote_identifier(column)}"
            f" AND NEW.{quote_identifier(column)} IS NOT NULL"
            for column in columns
        )
        clauses.append(f"({equality})")
    return " OR ".join(clauses)


def install_audit_triggers(conn: sqlite3.Connection) -> None:
    for table in sorted(AUDIT):
        if not conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
            (table,),
        ).fetchone():
            continue
        trigger_table = quote_identifier(table)
        statements = [
            (
                "insert",
                f"BEFORE INSERT ON {trigger_table} "
                f"WHEN EXISTS (SELECT 1 FROM main.{trigger_table} "
                f"WHERE {audit_insert_condition(conn, table)})",
            ),
            ("update", f"BEFORE UPDATE ON {trigger_table}"),
            ("delete", f"BEFORE DELETE ON {trigger_table}"),
        ]
        for suffix, clause in statements:
            name = f"vps_audit_no_{suffix}_{table}"
            if conn.execute(
                "SELECT 1 FROM sqlite_temp_master WHERE type='trigger' AND name=?",
                (name,),
            ).fetchone():
                continue
            conn.execute(
                f"CREATE TEMP TRIGGER {quote_identifier(name)} {clause} "
                "BEGIN SELECT RAISE(ABORT, 'audit append-only'); END"
            )


def install(
    conn: sqlite3.Connection,
    database: str,
    *,
    maintenance: bool | None = None,
    audit_path: str | None = None,
) -> None:
    maintenance = maintenance_enabled() if maintenance is None else maintenance
    destination = audit_path or os.environ.get("VPS_ADMIN_AUDIT_LOG")
    if not destination:
        raise RuntimeError("VPS_ADMIN_AUDIT_LOG is required")
    with open(destination, "a", encoding="utf-8"):
        pass
    os.chmod(destination, 0o600)
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA recursive_triggers=ON")
    conn.execute("PRAGMA busy_timeout=3000")
    conn.execute("PRAGMA synchronous=FULL")
    install_audit_triggers(conn)
    conn.set_authorizer(make_authorizer(maintenance))
    trace_state = {"sql": None, "changes": None}

    def trace(sql: str) -> None:
        operation = write_operation(sql)
        if operation is None:
            if first_keyword(sql) in {
                "BEGIN",
                "COMMIT",
                "END",
                "ROLLBACK",
                "RELEASE",
            }:
                trace_state["sql"] = None
                trace_state["changes"] = None
            return
        # SQLite 3.53 reports the authored statement once per trigger frame.
        # The duplicates share the same total_changes counter; a new
        # execution, including an identical statement, does not.
        changes = conn.total_changes
        if trace_state["sql"] == sql and trace_state["changes"] == changes:
            return
        trace_state["sql"] = sql
        trace_state["changes"] = changes
        try:
            log_write(database, sql, destination)
        except Exception:
            # sqlite3 ignores exceptions raised by trace callbacks. Interrupt
            # the statement as well so a failed audit write aborts the write
            # instead of silently letting it through.
            conn.interrupt()
            raise

    conn.set_trace_callback(trace)


def is_sensitive(table: str, column: str) -> bool:
    return (str(table).lower(), str(column).lower()) in SENSITIVE_COLUMNS


def masked(value):
    return "••••" if value is not None else value
