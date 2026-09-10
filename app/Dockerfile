FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Dependencias primero para aprovechar la cache de capas de Docker
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Usuario sin privilegios (buena práctica de seguridad de contenedores)
RUN useradd --create-home appuser
COPY . .
RUN chown -R appuser:appuser /app
USER appuser

# Cloud Run inyecta la variable PORT en tiempo de ejecución.
ENV PORT=8080
EXPOSE 8080

CMD exec gunicorn --bind :$PORT --workers 2 --threads 4 --timeout 0 wsgi:app
