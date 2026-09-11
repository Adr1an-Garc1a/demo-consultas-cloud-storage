#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Construyendo imagen con Cloud Build..."
gcloud builds submit "${REPO_ROOT}/app" \
  --tag="${IMAGE_NAME}:manual" \
  --project="${PROJECT_ID}"

echo "Desplegando a Cloud Run..."
# Sizing pensado para costo mínimo sin degradar la experiencia:
#   - min-instances=0: cero costo cuando nadie usa la app.
#   - max-instances=1: un solo contenedor como techo (evita facturación
#     por instancias concurrentes de sobra).
#   - memory=256Mi: la app solo firma URLs y responde JSON pequeño, nunca
#     mueve el contenido de los archivos.
#   - cpu-boost: acelera el arranque en frío (costo extra despreciable),
#     compensando la latencia que introduce min-instances=0.
# concurrency y gunicorn (workers/threads) se dejan en su valor original.
gcloud run deploy "${RUN_SERVICE}" \
  --image="${IMAGE_NAME}:manual" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --service-account="${SA_EMAIL}" \
  --allow-unauthenticated \
  --min-instances=0 \
  --max-instances=1 \
  --memory=256Mi \
  --cpu=1 \
  --cpu-boost \
  --set-env-vars="BUCKET_NAME=${BUCKET_NAME},GCP_PROJECT_ID=${PROJECT_ID}" \
  --set-secrets="FLASK_SECRET_KEY=${SECRET_FLASK_KEY}:latest,GOOGLE_CLIENT_ID=${SECRET_OAUTH_CLIENT_ID}:latest,GOOGLE_CLIENT_SECRET=${SECRET_OAUTH_CLIENT_SECRET}:latest,ALLOWED_EMAILS=${SECRET_ALLOWED_EMAILS}:latest"

echo ""
echo "URL del servicio:"
gcloud run services describe "${RUN_SERVICE}" --region="${REGION}" --format='value(status.url)'
echo ""
echo "IMPORTANTE: copia esa URL y regístrala en el OAuth Client ID de Google"
echo "(Authorized JavaScript origins + Authorized redirect URIs, agregando /auth/google/callback)."
