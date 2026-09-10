#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Construyendo imagen con Cloud Build..."
gcloud builds submit "${REPO_ROOT}/app" \
  --tag="${IMAGE_NAME}:manual" \
  --project="${PROJECT_ID}"

echo "Desplegando a Cloud Run..."
gcloud run deploy "${RUN_SERVICE}" \
  --image="${IMAGE_NAME}:manual" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --service-account="${SA_EMAIL}" \
  --allow-unauthenticated \
  --min-instances=0 \
  --max-instances=2 \
  --memory=512Mi \
  --set-env-vars="BUCKET_NAME=${BUCKET_NAME},GCP_PROJECT_ID=${PROJECT_ID}" \
  --set-secrets="FLASK_SECRET_KEY=${SECRET_FLASK_KEY}:latest,GOOGLE_CLIENT_ID=${SECRET_OAUTH_CLIENT_ID}:latest,GOOGLE_CLIENT_SECRET=${SECRET_OAUTH_CLIENT_SECRET}:latest,ALLOWED_EMAILS=${SECRET_ALLOWED_EMAILS}:latest"

echo ""
echo "URL del servicio:"
gcloud run services describe "${RUN_SERVICE}" --region="${REGION}" --format='value(status.url)'
echo ""
echo "IMPORTANTE: copia esa URL y regístrala en el OAuth Client ID de Google"
echo "(Authorized JavaScript origins + Authorized redirect URIs, agregando /auth/google/callback)."
