#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

# Prerrequisito manual (una sola vez, vía consola):
#   Cloud Build > Repositorios > Conectar repositorio > GitHub > autorizar
#   la GitHub App de Cloud Build sobre tu cuenta/organización y seleccionar
#   el repo. Esto no se puede automatizar por CLI porque requiere el flujo
#   de instalación de la GitHub App en el navegador.
#
# Reemplaza estos dos valores antes de ejecutar:
GITHUB_OWNER="TU_USUARIO_O_ORG_GITHUB"
GITHUB_REPO="TU_REPO_GITHUB"

# Cloud Build necesita permisos para desplegar en Cloud Run y para
# "actuar como" la Service Account de runtime.
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/run.admin" >/dev/null

gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/iam.serviceAccountUser" \
  --project="${PROJECT_ID}" >/dev/null

gcloud builds triggers create github \
  --name="${CB_TRIGGER}" \
  --repo-name="${GITHUB_REPO}" \
  --repo-owner="${GITHUB_OWNER}" \
  --branch-pattern="^main$" \
  --build-config="cloudbuild.yaml" \
  --substitutions="_IMAGE=${IMAGE_NAME},_SERVICE=${RUN_SERVICE},_REGION=${REGION},_SA_EMAIL=${SA_EMAIL},_BUCKET_NAME=${BUCKET_NAME}" \
  --project="${PROJECT_ID}"

echo "Trigger creado: ${CB_TRIGGER}. Cada push a 'main' construirá y desplegará automáticamente."
