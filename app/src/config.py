"""Configuración de la aplicación.

Todos los valores se leen desde variables de entorno. En Cloud Run, las
variables sensibles (FLASK_SECRET_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET,
ALLOWED_EMAILS) llegan inyectadas desde Secret Manager vía `--set-secrets`,
por lo que en tiempo de ejecución se ven como variables de entorno normales,
pero su valor NUNCA queda escrito en el código fuente ni en la imagen Docker.

Usar `os.environ[...]` (en vez de `.get(..., "valor_por_defecto")`) es
intencional: si falta una variable requerida, la app falla al arrancar en
vez de operar silenciosamente con un valor inventado.
"""

import os


def _parse_email_list(raw: str) -> list[str]:
    return [email.strip().lower() for email in raw.split(",") if email.strip()]


class Config:
    # --- Requeridas ---
    SECRET_KEY = os.environ["FLASK_SECRET_KEY"]
    GOOGLE_CLIENT_ID = os.environ["GOOGLE_CLIENT_ID"]
    BUCKET_NAME = os.environ["BUCKET_NAME"]
    GCP_PROJECT_ID = os.environ["GCP_PROJECT_ID"]

    # --- Opcionales ---
    GOOGLE_CLIENT_SECRET = os.environ.get("GOOGLE_CLIENT_SECRET", "")
    ALLOWED_EMAILS = _parse_email_list(os.environ.get("ALLOWED_EMAILS", ""))
    ALLOWED_DOMAIN = os.environ.get("ALLOWED_DOMAIN", "").lower()

    # --- Sesión ---
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"
    SESSION_COOKIE_SECURE = os.environ.get("FLASK_ENV") != "development"
    PERMANENT_SESSION_LIFETIME = 60 * 60 * 8  # 8 horas

    # --- Límites defensivos ---
    # Las subidas reales van directo a GCS vía Signed URL; este límite solo
    # protege los endpoints JSON del backend (no el tráfico de archivos).
    MAX_CONTENT_LENGTH = 1 * 1024 * 1024  # 1 MB

    SIGNED_URL_EXPIRATION_MINUTES = int(os.environ.get("SIGNED_URL_EXPIRATION_MINUTES", "15"))
