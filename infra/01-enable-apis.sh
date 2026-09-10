#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project="${PROJECT_ID}"

echo "APIs habilitadas."
