"""Punto de entrada usado por gunicorn en Cloud Run."""

from src import create_app

app = create_app()

if __name__ == "__main__":
    # Solo para pruebas locales: `python wsgi.py`
    app.run(host="0.0.0.0", port=8080, debug=True)
