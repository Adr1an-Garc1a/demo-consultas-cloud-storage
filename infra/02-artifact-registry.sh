#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

gcloud artifacts repositories create "${AR_REPO}" \
  --repository-format=docker \
  --location="${REGION}" \
  --description="Imágenes Docker de la app demo-consultas-cloud-storage" \
  --project="${PROJECT_ID}"

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

echo "Artifact Registry listo: ${AR_REPO}"
