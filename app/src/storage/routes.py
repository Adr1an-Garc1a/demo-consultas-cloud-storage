from flask import Blueprint, current_app, jsonify, render_template, request, session

from ..auth.decorators import login_required
from .gcs_service import GCSService

storage_bp = Blueprint("storage", __name__)


def _service() -> GCSService:
    return GCSService(
        bucket_name=current_app.config["BUCKET_NAME"],
        signed_url_minutes=current_app.config["SIGNED_URL_EXPIRATION_MINUTES"],
    )


@storage_bp.get("/")
@login_required
def dashboard():
    return render_template("dashboard.html", user=session["user"])


@storage_bp.get("/api/files")
@login_required
def list_files():
    return jsonify(_service().list_files())


@storage_bp.post("/api/files/upload-url")
@login_required
def get_upload_url():
    data = request.get_json(silent=True) or {}
    filename = (data.get("filename") or "").strip()
    content_type = data.get("content_type") or "application/octet-stream"

    if not filename:
        return jsonify({"error": "filename es requerido"}), 400
    if "/" in filename or ".." in filename:
        return jsonify({"error": "Nombre de archivo no válido"}), 400

    url = _service().generate_upload_url(filename, content_type)
    return jsonify({"upload_url": url, "filename": filename})


@storage_bp.get("/api/files/<path:filename>/download-url")
@login_required
def get_download_url(filename: str):
    url = _service().generate_download_url(filename)
    return jsonify({"download_url": url})


@storage_bp.delete("/api/files/<path:filename>")
@login_required
def delete_file(filename: str):
    _service().delete_file(filename)
    return jsonify({"status": "eliminado", "filename": filename})
