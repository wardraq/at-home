"""Mobile-facing API routes (:6060)."""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

from flask import Blueprint, request
from werkzeug.utils import secure_filename

from server import APP_VERSION
from server.api.responses import error, ok
from server.storage import build_relative_path, infer_extension, save_upload_file
from server.store import AppContext
from server.version import decide_version

VALID_PARTS = {"image", "video"}


def create_mobile_blueprint(ctx: AppContext) -> Blueprint:
    bp = Blueprint("mobile", __name__)

    @bp.get("/ping")
    def ping():
        return ok(serverId=ctx.config.server_id, version=APP_VERSION)

    @bp.post("/handshake")
    def handshake():
        body = request.get_json(silent=True) or {}
        user_id = body.get("userId")
        device_name = body.get("deviceName")
        if not user_id or not device_name:
            return error("MISSING_FIELD", "userId and deviceName are required", 400)

        user = ctx.config.get_user(user_id)
        if user is None:
            return error("USER_NOT_FOUND", "用户未授权", 401)
        if user.get("status") != "active":
            return error("USER_REVOKED", "用户已被吊销", 403)

        session = ctx.sessions.issue(user_id, device_name)
        return ok(
            serverId=ctx.config.server_id,
            sessionToken=session["token"],
            userName=user["name"],
            expiresAt=session["expiresAt"],
        )

    @bp.post("/upload")
    def upload():
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return error("INVALID_TOKEN", "缺少或无效的 sessionToken", 401)

        token = auth[7:].strip()
        session = ctx.sessions.validate(token)
        if session is None:
            return error("TOKEN_EXPIRED", "会话已过期，请重新握手", 401)

        user = ctx.config.get_user(session["userId"])
        if user is None:
            return error("INVALID_TOKEN", "用户不存在", 401)
        if user.get("status") != "active":
            return error("USER_REVOKED", "用户已被吊销", 403)

        upload_file = request.files.get("file")
        local_identifier = request.form.get("localIdentifier")
        modification_date = request.form.get("modificationDate")
        creation_date = request.form.get("creationDate")
        part = request.form.get("part")
        original_filename = request.form.get("originalFilename")
        mime_type = request.form.get("mimeType")

        missing = [
            name
            for name, value in [
                ("file", upload_file),
                ("localIdentifier", local_identifier),
                ("modificationDate", modification_date),
                ("creationDate", creation_date),
                ("part", part),
            ]
            if not value
        ]
        if missing:
            return error("MISSING_FIELD", f"缺少必填字段: {', '.join(missing)}", 400)

        if part not in VALID_PARTS:
            return error("INVALID_PART", "part 必须为 image 或 video", 400)

        decision = decide_version(
            ctx.metadata,
            user["id"],
            local_identifier,
            modification_date,
        )
        if decision.regression:
            return error(
                "MODIFICATION_REGRESSION",
                "modificationDate 早于已记录值",
                409,
            )

        extension = infer_extension(original_filename, mime_type)
        relative_path = build_relative_path(
            user["name"],
            creation_date,
            local_identifier,
            decision.version,
            part,
            extension,
        )

        suffix = Path(secure_filename(upload_file.filename or f"upload.{extension}")).suffix
        if not suffix:
            suffix = f".{extension}"

        tmp_fd, tmp_name = tempfile.mkstemp(suffix=suffix)
        os.close(tmp_fd)
        tmp_path = Path(tmp_name)
        try:
            upload_file.save(tmp_path)
            file_size = tmp_path.stat().st_size
            save_upload_file(ctx.config.storage_path, relative_path, tmp_path)
        except OSError:
            if tmp_path.exists():
                tmp_path.unlink()
            return error("STORAGE_ERROR", "写入磁盘失败", 500)
        finally:
            if tmp_path.exists():
                tmp_path.unlink()

        ctx.metadata.upsert_asset(
            user_id=user["id"],
            local_identifier=local_identifier,
            version=decision.version,
            modification_date=modification_date,
            creation_date=creation_date,
            original_filename=original_filename,
        )
        ctx.metadata.upsert_upload(
            user_id=user["id"],
            local_identifier=local_identifier,
            version=decision.version,
            part=part,
            modification_date=modification_date,
            file_path=relative_path,
            file_size=file_size,
        )

        from datetime import datetime, timezone

        uploaded_at = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
        return ok(
            localIdentifier=local_identifier,
            version=decision.version,
            part=part,
            path=relative_path,
            uploadedAt=uploaded_at,
        )

    return bp
