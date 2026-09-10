"""Verificación de identidad usando Google Identity Services (Google Sign-In).

No se implementa un backend de usuarios propio ni contraseñas: la única
fuente de verdad de identidad es el ID token que Google firma y entrega al
navegador tras el login. Aquí se valida esa firma y se decide si el correo
autenticado tiene permiso de usar la aplicación.
"""

from flask import current_app
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

_request_adapter = google_requests.Request()


class InvalidTokenError(Exception):
    """El token no es válido, expiró, o el correo no está autorizado."""


def verify_google_token(token: str) -> dict:
    try:
        claims = id_token.verify_oauth2_token(
            token, _request_adapter, current_app.config["GOOGLE_CLIENT_ID"]
        )
    except ValueError as exc:
        raise InvalidTokenError("Token de Google inválido o expirado") from exc

    if not claims.get("email_verified", False):
        raise InvalidTokenError("El correo de Google no está verificado")

    _assert_authorized(claims["email"].lower())
    return claims


def _assert_authorized(email: str) -> None:
    allowed_emails = current_app.config["ALLOWED_EMAILS"]
    allowed_domain = current_app.config["ALLOWED_DOMAIN"]

    if allowed_emails or allowed_domain:
        if email in allowed_emails:
            return
        if allowed_domain and email.endswith("@" + allowed_domain):
            return
        raise InvalidTokenError("Este correo no está autorizado para usar la aplicación")

    # Sin ALLOWED_EMAILS ni ALLOWED_DOMAIN configurados: cualquier cuenta de
    # Google válida entra. Útil solo para una demo rápida; en un despliegue
    # real siempre se debe configurar al menos una de las dos restricciones.
