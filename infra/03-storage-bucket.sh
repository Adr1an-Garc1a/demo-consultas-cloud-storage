#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${BUCKET_NAME}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --default-storage-class=STANDARD \
    --uniform-bucket-level-access \
    --public-access-prevention
else
  echo "Ya existe: gs://${BUCKET_NAME}"
fi

# Versionado: protege contra borrados/edits accidentales desde la app
gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning

# Ciclo de vida: purga versiones antiguas a los 30 días. Da margen de
# sobra para recuperar un archivo borrado/editado por error.
cat > /tmp/lifecycle-${BUCKET_NAME}.json <<'EOF'
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"isLive": false, "daysSinceNoncurrentTime": 30}
    }
  ]
}
EOF
gcloud storage buckets update "gs://${BUCKET_NAME}" \
  --lifecycle-file="/tmp/lifecycle-${BUCKET_NAME}.json"

echo "Bucket listo: gs://${BUCKET_NAME}"
