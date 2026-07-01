#!/usr/bin/env python3
"""AtHome photo receiver — dual-port HTTP server."""

from __future__ import annotations

import argparse
import sys
import threading
from pathlib import Path

from flask import Flask
from werkzeug.serving import make_server

# Allow `python receive.py` from server/ directory.
_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from server.api.admin import create_admin_blueprint  # noqa: E402
from server.api.mobile import create_mobile_blueprint  # noqa: E402
from server.store import AppContext  # noqa: E402

MAX_UPLOAD_BYTES = 500 * 1024 * 1024


def _build_mobile_app(ctx: AppContext) -> Flask:
    app = Flask("athome-mobile")
    app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_BYTES
    app.register_blueprint(create_mobile_blueprint(ctx))
    return app


def _build_admin_app(ctx: AppContext) -> Flask:
    template_folder = str(Path(__file__).resolve().parent / "templates")
    app = Flask("athome-admin", template_folder=template_folder)
    app.register_blueprint(create_admin_blueprint(ctx, template_folder))
    return app


def _run_server(app: Flask, host: str, port: int) -> None:
    server = make_server(host, port, app)
    server.serve_forever()


def main() -> None:
    parser = argparse.ArgumentParser(description="AtHome photo receiver server")
    default_data_dir = Path(__file__).resolve().parent / "data"
    parser.add_argument("--data-dir", type=Path, default=default_data_dir)
    parser.add_argument("--storage-path", type=Path, default=None)
    parser.add_argument("--api-port", type=int, default=None)
    parser.add_argument("--admin-port", type=int, default=None)
    args = parser.parse_args()

    data_dir: Path = args.data_dir
    data_dir.mkdir(parents=True, exist_ok=True)
    storage_path = args.storage_path or (data_dir / "photos")

    ctx = AppContext(data_dir, storage_path)
    if args.api_port is not None:
        ctx.config.api_port = args.api_port
    if args.admin_port is not None:
        ctx.config.admin_port = args.admin_port

    api_port = ctx.config.api_port
    admin_port = ctx.config.admin_port

    mobile_app = _build_mobile_app(ctx)
    admin_app = _build_admin_app(ctx)

    admin_thread = threading.Thread(
        target=_run_server,
        args=(admin_app, "127.0.0.1", admin_port),
        daemon=True,
        name="admin-server",
    )
    admin_thread.start()

    print(f"AtHome receiver started")
    print(f"  Mobile API: http://0.0.0.0:{api_port}  (LAN: http://{ctx.lan_ip}:{api_port})")
    print(f"  Admin UI:   http://127.0.0.1:{admin_port}")
    print(f"  Storage:    {ctx.config.storage_path}")
    print(f"  serverId:   {ctx.config.server_id}")

    _run_server(mobile_app, "0.0.0.0", api_port)


if __name__ == "__main__":
    main()
