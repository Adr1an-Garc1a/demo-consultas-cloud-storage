#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

if ! gcloud artifacts repositories describe "${AR_REPO}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud artifacts repositories create "${AR_REPO}" \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Imágenes Docker de la app demo-consultas-cloud-storage" \
    --project="${PROJECT_ID}"
else
  echo "Ya existe: ${AR_REPO}"
fi

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# Política de limpieza: sin esto, cada build (manual o por CI/CD) deja una
# imagen nueva acumulando almacenamiento indefinidamente. Se conservan las
# 5 versiones más recientes y se borran las no etiquetadas con más de 7
# días (las que ya no son ni "latest" ni una versión de git referenciada).
CLEANUP_POLICY_FILE="/tmp/ar-cleanup-${AR_REPO}.json"
cat > "${CLEANUP_POLICY_FILE}" <<'EOF'
[
  {
    "name": "keep-most-recent-5",
    "action": {"type": "Keep"},
    "mostRecentVersions": {"keepCount": 5}
  },
  {
    "name": "delete-old-untagged",
    "action": {"type": "Delete"},
    "condition": {"tagState": "UNTAGGED", "olderThan": "604800s"}
  }
]
EOF

gcloud artifacts repositories set-cleanup-policies "${AR_REPO}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --policy="${CLEANUP_POLICY_FILE}"

echo "Artifact Registry listo (con política de limpieza): ${AR_REPO}"
