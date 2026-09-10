"""Application factory.

Se usa el patrón `create_app()` (en vez de un `app = Flask(__name__)` a nivel
de módulo) para poder instanciar la app de forma aislada en los tests y para
mantener la configuración centralizada en un solo punto (src/config.py).
"""

from flask import Flask

from .config import Config


def create_app(config_object: type = Config) -> Flask:
    app = Flask(
        __name__,
        template_folder="templates",
        static_folder="static",
        static_url_path="/static",
    )
    app.config.from_object(config_object)

    _register_blueprints(app)
    _register_health_check(app)

    return app


def _register_blueprints(app: Flask) -> None:
    from .auth.routes import auth_bp
    from .storage.routes import storage_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(storage_bp)


def _register_health_check(app: Flask) -> None:
    @app.get("/healthz")
    def healthz():
        return {"status": "ok"}, 200
