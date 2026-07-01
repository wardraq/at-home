"""JSON response helpers."""

from __future__ import annotations

from flask import jsonify


def ok(**fields):
    payload = {"status": "ok", **fields}
    return jsonify(payload), 200


def error(code: str, message: str, http_status: int):
    return jsonify({"status": "error", "code": code, "message": message}), http_status
