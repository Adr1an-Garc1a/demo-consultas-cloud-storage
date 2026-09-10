#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

gcloud iam service-accounts create "${SA_NAME}" \
  --display-name="SA demo consultas cloud storage" \
  --description="Identidad de runtime de Cloud Run, con permisos acotados al bucket bck-demo-consultas-cloud-storage" \
  --project="${PROJECT_ID}"

# Least privilege: el rol se otorga SOLO sobre el bucket, no a nivel proyecto.
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"

# Necesario para que la propia SA pueda firmar Signed URLs (V4) sin exportar llaves.
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="${PROJECT_ID}"

echo "Service Account lista: ${SA_EMAIL}"
