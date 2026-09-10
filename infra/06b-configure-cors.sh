#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

# Las subidas/descargas van del navegador directo a Cloud Storage (Signed
# URLs), por lo que son peticiones cross-origin. Sin una política CORS en
# el bucket, el navegador las bloquea silenciosamente (no da error de
# servidor: el fetch() nunca llega a salir).

RUN_URL="$(gcloud run services describe "${RUN_SERVICE}" \
  --region="${REGION}" --project="${PROJECT_ID}" \
  --format='value(status.url)')"

if [[ -z "${RUN_URL}" ]]; then
  echo "No se encontró el servicio de Cloud Run. Corre primero ./06-build-and-deploy.sh" >&2
  exit 1
fi

CORS_FILE="/tmp/cors-${BUCKET_NAME}.json"
cat > "${CORS_FILE}" <<EOF
[
  {
    "origin": ["${RUN_URL}"],
    "method": ["GET", "PUT", "OPTIONS"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
EOF

gcloud storage buckets update "gs://${BUCKET_NAME}" \
  --cors-file="${CORS_FILE}" \
  --project="${PROJECT_ID}"

echo "CORS configurado en gs://${BUCKET_NAME} para el origen: ${RUN_URL}"
echo "Si más adelante mapeas un dominio propio a Cloud Run, vuelve a correr este script."
