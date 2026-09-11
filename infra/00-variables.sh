#!/usr/bin/env bash
# Variables compartidas por todos los scripts de infra/.
# Ningún valor sensible vive aquí: solo nombres/IDs de recursos.
# Uso: source ./00-variables.sh

export PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "No hay un proyecto activo en gcloud. Ejecuta: gcloud config set project TU_PROJECT_ID" >&2
  return 1 2>/dev/null || exit 1
fi

export PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
export REGION="us-central1"

# --- Nomenclatura: <abreviatura>-demo-consultas-cloud-storage ---
export BUCKET_NAME="bck-demo-consultas-cloud-storage-adr"
export AR_REPO="ar-demo-consultas-cloud-storage-adr"
export RUN_SERVICE="run-demo-consultas-cloud-storage-adr"
export CB_TRIGGER="cb-demo-consultas-cloud-storage-adr"

# El Service Account ID tiene un límite duro de GCP de 30 caracteres,
# por eso aquí se abrevia "cloud-storage" -> "cs".
export SA_NAME="sa-demo-consultas-cs-adr"
export SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Secretos en Secret Manager
export SECRET_FLASK_KEY="sm-demo-consultas-cloud-storage-flask-secret"
export SECRET_OAUTH_CLIENT_ID="sm-demo-consultas-cloud-storage-oauth-client-id"
export SECRET_OAUTH_CLIENT_SECRET="sm-demo-consultas-cloud-storage-oauth-client-secret"
export SECRET_ALLOWED_EMAILS="sm-demo-consultas-cloud-storage-allowed-emails"

export IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${RUN_SERVICE}"

echo "PROJECT_ID=${PROJECT_ID}"
echo "REGION=${REGION}"
echo "BUCKET_NAME=${BUCKET_NAME}"
echo "SA_EMAIL=${SA_EMAIL}"
echo "IMAGE_NAME=${IMAGE_NAME}"
