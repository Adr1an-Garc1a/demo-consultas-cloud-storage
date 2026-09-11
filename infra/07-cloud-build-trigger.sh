#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

# Prerrequisito manual (una sola vez, vía consola):
#   Cloud Build > Repositorios > Conectar host > GitHub > autoriza la
#   GitHub App, crea una CONEXIÓN de 2a generación (región = "${REGION}",
#   "global" no es válido) y vincula tu repositorio dentro de esa conexión.
#   Esto no se puede automatizar por CLI porque requiere el flujo de
#   autorización OAuth de GitHub en el navegador.
#
# Reemplaza estos dos valores con lo que hayas creado en la consola:
CONNECTION_NAME="adr-garcia-github-demos"   # nombre que le diste a la conexión
GITHUB_REPO="demo-consultas-cloud-storage"           # nombre del repo tal como quedó vinculado

REPOSITORY_RESOURCE="projects/${PROJECT_ID}/locations/${REGION}/connections/${CONNECTION_NAME}/repositories/${GITHUB_REPO}"

# Cloud Build necesita permisos para desplegar en Cloud Run y para
# "actuar como" la Service Account de runtime.
# --condition=None evita el prompt de "policy contains bindings with
# conditions" en proyectos que ya tienen bindings condicionales.
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/run.admin" \
  --condition=None >/dev/null

gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/iam.serviceAccountUser" \
  --project="${PROJECT_ID}" \
  --condition=None >/dev/null

gcloud builds triggers create github \
  --name="${CB_TRIGGER}" \
  --region="${REGION}" \
  --repository="${REPOSITORY_RESOURCE}" \
  --branch-pattern="^main$" \
  --build-config="cloudbuild.yaml" \
  --substitutions="_IMAGE=${IMAGE_NAME},_SERVICE=${RUN_SERVICE},_REGION=${REGION},_SA_EMAIL=${SA_EMAIL},_BUCKET_NAME=${BUCKET_NAME}" \
  --project="${PROJECT_ID}"

echo "Trigger creado: ${CB_TRIGGER}. Cada push a 'main' construirá y desplegará automáticamente."
