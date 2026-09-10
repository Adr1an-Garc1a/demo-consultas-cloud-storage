from flask import Blueprint, current_app, redirect, render_template, request, session, url_for

from .google_oauth import InvalidTokenError, verify_google_token

auth_bp = Blueprint("auth", __name__)


@auth_bp.get("/login")
def login_page():
    if "user" in session:
        return redirect(url_for("storage.dashboard"))
    return render_template(
        "login.html",
        google_client_id=current_app.config["GOOGLE_CLIENT_ID"],
    )


@auth_bp.post("/auth/google/callback")
def google_callback():
    """Recibe el ID token que el botón de Google Identity Services envía
    directamente por POST (data-ux_mode="redirect")."""
    token = request.form.get("credential")
    if not token:
        return render_template("login.html", error="No se recibió el credential de Google.",
                                google_client_id=current_app.config["GOOGLE_CLIENT_ID"]), 400

    try:
        claims = verify_google_token(token)
    except InvalidTokenError as exc:
        return render_template("login.html", error=str(exc),
                                google_client_id=current_app.config["GOOGLE_CLIENT_ID"]), 401

    session.clear()
    session["user"] = {
        "email": claims["email"],
        "name": claims.get("name", claims["email"]),
        "picture": claims.get("picture", ""),
    }
    session.permanent = True
    return redirect(url_for("storage.dashboard"))


@auth_bp.post("/logout")
def logout():
    session.clear()
    return redirect(url_for("auth.login_page"))
