"""Admin API and Web UI (:6061)."""

from __future__ import annotations

import io
import json
import shutil
from pathlib import Path

import qrcode
from flask import Blueprint, render_template, request, send_file

from server.api.responses import error, ok
from server.store import AppContext


def create_admin_blueprint(ctx: AppContext, template_folder: str) -> Blueprint:
    bp = Blueprint("admin", __name__, template_folder=template_folder)

    @bp.get("/")
    def index():
        return render_template("index.html")

    @bp.get("/admin/status")
    def status():
        storage_path = ctx.config.storage_path
        disk_free = shutil.disk_usage(storage_path if storage_path.exists() else "/").free
        return ok(
            serverId=ctx.config.server_id,
            apiAddr=ctx.api_addr(),
            storagePath=str(storage_path),
            diskFreeBytes=disk_free,
            uptime=ctx.uptime_seconds(),
        )

    @bp.put("/admin/settings")
    def settings():
        body = request.get_json(silent=True) or {}
        storage_path = body.get("storagePath")
        if not storage_path:
            return error("MISSING_FIELD", "storagePath is required", 400)
        ctx.config.storage_path = Path(storage_path)
        return ok(storagePath=str(ctx.config.storage_path))

    @bp.get("/admin/users")
    def list_users():
        users = []
        for user in ctx.config.list_users():
            users.append(
                {
                    "userId": user["id"],
                    "name": user["name"],
                    "status": user["status"],
                    "createdAt": user["createdAt"],
                    "assetCount": ctx.metadata.count_assets(user["id"]),
                    "lastUploadAt": ctx.metadata.last_upload_at(user["id"]),
                }
            )
        return ok(users=users)

    @bp.post("/admin/users")
    def create_user():
        body = request.get_json(silent=True) or {}
        name = (body.get("name") or "").strip()
        if not name:
            return error("MISSING_FIELD", "name is required", 400)
        try:
            user = ctx.config.create_user(name)
        except ValueError as exc:
            return error("MISSING_FIELD", str(exc), 400)

        return ok(
            userId=user["id"],
            name=user["name"],
            qrPayload=ctx.qr_payload(user["id"]),
        )

    @bp.delete("/admin/users/<user_id>")
    def revoke_user(user_id: str):
        user = ctx.config.revoke_user(user_id)
        if user is None:
            return error("USER_NOT_FOUND", "用户未授权", 401)
        ctx.sessions.revoke_user(user_id)
        return ok(userId=user_id, status="revoked")

    @bp.get("/admin/users/<user_id>/qrcode")
    def qrcode_for_user(user_id: str):
        user = ctx.config.get_user(user_id)
        if user is None:
            return error("USER_NOT_FOUND", "用户未授权", 401)

        payload = ctx.qr_payload(user_id)
        if request.accept_mimetypes.best_match(["application/json", "image/png"]) == "image/png":
            image = qrcode.make(json.dumps(payload, ensure_ascii=False))
            buffer = io.BytesIO()
            image.save(buffer, format="PNG")
            buffer.seek(0)
            return send_file(buffer, mimetype="image/png")

        return ok(qrPayload=payload)

    @bp.get("/admin/uploads/recent")
    def recent_uploads():
        limit = request.args.get("limit", default=50, type=int)
        uploads = []
        user_names = {u["id"]: u["name"] for u in ctx.config.list_users()}
        for row in ctx.metadata.recent_uploads(limit):
            uploads.append(
                {
                    "userId": row["user_id"],
                    "userName": user_names.get(row["user_id"], row["user_id"]),
                    "localIdentifier": row["local_identifier"],
                    "version": row["version"],
                    "part": row["part"],
                    "path": row["file_path"],
                    "fileSize": row["file_size"],
                    "uploadedAt": row["uploaded_at"],
                }
            )
        return ok(uploads=uploads)

    return bp
