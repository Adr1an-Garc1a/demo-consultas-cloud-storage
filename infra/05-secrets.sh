#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-variables.sh"

# 1) Flask secret key: se genera al vuelo, nunca queda escrita en ningún archivo.
if ! gcloud secrets describe "${SECRET_FLASK_KEY}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  openssl rand -base64 32 | gcloud secrets create "${SECRET_FLASK_KEY}" \
    --data-file=- \
    --replication-policy="automatic" \
    --project="${PROJECT_ID}"
  echo "Secreto creado: ${SECRET_FLASK_KEY}"
else
  echo "Ya existe: ${SECRET_FLASK_KEY}"
fi

# 2) OAuth Client ID / Secret: estos valores salen de la consola de Google Cloud
#    (APIs & Services > Credentials > OAuth client ID > Web application).
#    Aquí solo se crea el "contenedor" del secreto; la primera versión se
#    agrega a mano para no dejar el valor en texto plano en ningún script.
for SECRET in "${SECRET_OAUTH_CLIENT_ID}" "${SECRET_OAUTH_CLIENT_SECRET}" "${SECRET_ALLOWED_EMAILS}"; do
  if ! gcloud secrets describe "${SECRET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    gcloud secrets create "${SECRET}" \
      --replication-policy="automatic" \
      --project="${PROJECT_ID}"
    echo "Secreto creado (vacío, agrega su valor con 'versions add'): ${SECRET}"
  else
    echo "Ya existe: ${SECRET}"
  fi
done

echo ""
echo "Para cargar los valores reales (hazlo interactivo, no los pegues en un script):"
echo "  printf '%s' 'TU_CLIENT_ID.apps.googleusercontent.com' | gcloud secrets versions add ${SECRET_OAUTH_CLIENT_ID} --data-file=-"
echo "  printf '%s' 'TU_CLIENT_SECRET' | gcloud secrets versions add ${SECRET_OAUTH_CLIENT_SECRET} --data-file=-"
echo "  printf '%s' 'usuario1@clientedominio.com,usuario2@clientedominio.com' | gcloud secrets versions add ${SECRET_ALLOWED_EMAILS} --data-file=-"

echo ""
echo "Otorgando acceso de lectura a la Service Account de runtime..."
for SECRET in "${SECRET_FLASK_KEY}" "${SECRET_OAUTH_CLIENT_ID}" "${SECRET_OAUTH_CLIENT_SECRET}" "${SECRET_ALLOWED_EMAILS}"; do
  gcloud secrets add-iam-policy-binding "${SECRET}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/secretmanager.secretAccessor" \
    --project="${PROJECT_ID}" >/dev/null
done
echo "Listo."
