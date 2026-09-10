from functools import wraps

from flask import jsonify, redirect, request, session, url_for


def login_required(view_func):
    """Exige una sesión válida; distingue rutas de API (JSON 401) de páginas (redirect)."""

    @wraps(view_func)
    def wrapped(*args, **kwargs):
        if "user" not in session:
            if request.path.startswith("/api/"):
                return jsonify({"error": "No autenticado"}), 401
            return redirect(url_for("auth.login_page"))
        return view_func(*args, **kwargs)

    return wrapped
