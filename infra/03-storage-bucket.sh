#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --default-storage-class=STANDARD \
  --uniform-bucket-level-access \
  --public-access-prevention

# Versionado: protege contra borrados/edits accidentales desde la app
gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning

# Ciclo de vida de ejemplo: purga versiones antiguas después de 30 días
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
