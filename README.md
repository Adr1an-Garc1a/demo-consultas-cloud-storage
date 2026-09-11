# Demo · Consultas Cloud Storage

Aplicación web para que un cliente no técnico suba, vea y borre sus
documentos con una experiencia tipo "arrastrar y soltar" (como Google
Drive), pero respaldada por Cloud Storage, sin el límite de almacenamiento
de Drive.

## Arquitectura

```
Navegador ──(Google Sign-In)──▶ Cloud Run (Flask)
                                   │  verifica ID token, gestiona sesión
                                   │  emite Signed URLs (V4)
                                   ▼
                          Cloud Storage (bucket)
                                   ▲
Navegador ──(PUT/GET directo, sin pasar por Cloud Run)──┘
```

- **Cloud Run** sirve la interfaz y una API mínima (`/api/files*`). No
  mueve el contenido de los archivos: solo emite Signed URLs para que el
  navegador suba/descargue directo contra el bucket.
- **Cloud Storage** guarda los documentos, con versionado y una regla de
  ciclo de vida de ejemplo.
- **Secret Manager** guarda todo valor sensible; nada vive en el código ni
  en la imagen Docker.
- **Identidad**: exclusivamente Google Sign-In (Google Identity Services).
  No hay usuarios/contraseñas propios ni IAP.
- **Artifact Registry + Cloud Build**: build de la imagen y despliegue
  continuo desde GitHub.

## Nomenclatura de recursos

| Recurso | Nombre |
|---|---|
| Bucket | `bck-demo-consultas-cloud-storage` |
| Cloud Run | `run-demo-consultas-cloud-storage` |
| Artifact Registry | `ar-demo-consultas-cloud-storage` |
| Service Account | `sa-demo-consultas-cs` *(abreviado por el límite de 30 caracteres de IAM)* |
| Cloud Build trigger | `cb-demo-consultas-cloud-storage` |
| Secretos | `sm-demo-consultas-cloud-storage-*` |

## 1. Crear la infraestructura (Cloud Shell)

Ejecuta en orden desde `infra/`. Todos los scripts leen `00-variables.sh`,
así que solo necesitas cambiar el proyecto activo de `gcloud`, no editar
nombres de recursos.

```bash
gcloud config set project TU_PROJECT_ID
cd infra
chmod +x *.sh

./01-enable-apis.sh
./02-artifact-registry.sh
./03-storage-bucket.sh
./04-service-account.sh
./05-secrets.sh          # crea los "contenedores" de secretos
```

### Paso manual obligatorio: OAuth Client ID de Google

Google Sign-In requiere un OAuth Client ID de tipo *Web application*, que
hoy en día solo se crea desde la consola (no hay comando público de
`gcloud` para este tipo de credencial):

1. Consola de Google Cloud → **APIs & Services → Credentials → Create
   Credentials → OAuth client ID → Web application**.
2. Déjalo abierto; añadirás los orígenes/redirects autorizados **después**
   del primer deploy, cuando ya tengas la URL real de Cloud Run.
3. Copia el *Client ID* y el *Client secret* y cárgalos al secreto (hazlo
   de forma interactiva, nunca los pegues en un script versionado):

   ```bash
   printf '%s' 'TU_CLIENT_ID.apps.googleusercontent.com' | \
     gcloud secrets versions add sm-demo-consultas-cloud-storage-oauth-client-id --data-file=-

   printf '%s' 'TU_CLIENT_SECRET' | \
     gcloud secrets versions add sm-demo-consultas-cloud-storage-oauth-client-secret --data-file=-

   printf '%s' 'usuario1@clientedominio.com,usuario2@clientedominio.com' | \
     gcloud secrets versions add sm-demo-consultas-cloud-storage-allowed-emails --data-file=-
   ```

### Primer build + deploy manual

```bash
./06-build-and-deploy.sh
```

Al final imprime la URL del servicio. **Vuelve a la pantalla de
Credentials de Google** y agrega:
- *Authorized JavaScript origins*: la URL de Cloud Run.
- *Authorized redirect URIs*: la misma URL + `/auth/google/callback`.

### CORS del bucket (imprescindible para subir/ver archivos)

Las subidas y descargas van del navegador **directo** a Cloud Storage vía
Signed URLs, así que son peticiones cross-origin. Sin esto, subir un
archivo falla en silencio (el navegador bloquea la petición antes de que
salga, sin mostrar error de servidor):

```bash
./06b-configure-cors.sh
```

Vuelve a correrlo si más adelante cambias de región, de nombre de servicio,
o mapeas un dominio propio a Cloud Run.

### CI/CD desde GitHub (opcional pero recomendado)

1. Sube este repo a GitHub.
2. En la consola: **Cloud Build → Repositorios → Conectar host → GitHub**,
   autoriza la GitHub App y crea una **conexión de 2ª generación** (usa la
   misma región que `REGION`, `global` no es válido para 2nd gen). Vincula
   tu repositorio dentro de esa conexión (paso único, requiere navegador).
3. Edita `infra/07-cloud-build-trigger.sh` con el nombre de la conexión y
   del repo tal como quedaron en la consola, y ejecútalo:

   ```bash
   ./07-cloud-build-trigger.sh
   ```

Desde ese momento, cada push a `main` reconstruye la imagen en Artifact
Registry y despliega automáticamente a Cloud Run (`cloudbuild.yaml`).

## 2. Estructura de la aplicación

```
app/
├── Dockerfile
├── requirements.txt / requirements-dev.txt
├── wsgi.py                 # entrypoint de gunicorn
├── src/
│   ├── config.py            # toda la config viene de variables de entorno
│   ├── auth/
│   │   ├── google_oauth.py  # verifica el ID token de Google
│   │   ├── decorators.py    # @login_required
│   │   └── routes.py        # /login, /auth/google/callback, /logout
│   ├── storage/
│   │   ├── gcs_service.py   # Signed URLs V4 (upload/download)
│   │   └── routes.py        # /, /api/files*
│   ├── templates/
│   └── static/
└── tests/
```

## 3. Correr localmente

```bash
cd app
python -m venv venv && source venv/bin/activate
pip install -r requirements-dev.txt

export FLASK_SECRET_KEY="dev-secret"
export GOOGLE_CLIENT_ID="tu-client-id.apps.googleusercontent.com"
export BUCKET_NAME="bck-demo-consultas-cloud-storage"
export GCP_PROJECT_ID="tu-project-id"
export FLASK_ENV="development"
export GOOGLE_APPLICATION_CREDENTIALS="ruta/a/tu/key.json"  # solo local

python wsgi.py
```

```bash
pytest
```

## Seguridad implementada

- Ningún secreto ni ID de proyecto está escrito en el código: todo llega
  por variables de entorno inyectadas desde Secret Manager.
- La Service Account de Cloud Run solo tiene `roles/storage.objectAdmin`
  **sobre ese bucket específico** (no a nivel proyecto).
- El contenido de los archivos nunca pasa por la memoria de Cloud Run
  (Signed URLs V4 para subida y descarga directa contra GCS).
- `ALLOWED_EMAILS` / `ALLOWED_DOMAIN` restringen qué cuentas de Google
  pueden entrar, incluso si el servicio de Cloud Run es públicamente
  invocable (necesario porque la autenticación ocurre a nivel de
  aplicación, no de IAM).
- Bucket con acceso público bloqueado (`--public-access-prevention`),
  acceso uniforme a nivel de bucket y versionado activado.

## Costos: qué se optimizó y por qué

| Recurso | Configuración | Razonamiento |
|---|---|---|
| Cloud Run `min-instances` | `0` | Cero costo cuando nadie usa la app. |
| Cloud Run `max-instances` | `1` | Techo de un solo contenedor activo a la vez. |
| Cloud Run `memory` / `cpu` | `256Mi` / `1` | La app solo firma URLs y responde JSON pequeño; nunca mueve el contenido de los archivos. |
| Cloud Run `concurrency` | default (80) | Sin cambios respecto al original. |
| Gunicorn | 2 workers × 4 threads | Sin cambios respecto al original. |
| Cloud Run `cpu-boost` | activado | Costo extra despreciable; compensa la latencia de arranque en frío que introduce `min-instances=0`. |
| Bucket | `STANDARD`, single-region | Más barato que Nearline/Coldline para acceso frecuente, y sin cargos de recuperación anticipada. |
| Cloud Run y bucket | misma región | Evita cargos de egress entre regiones. |
| Subida/descarga de archivos | Signed URLs directo navegador↔GCS | Cloud Run nunca transfiere bytes de archivos: cero egress ahí. |
| Artifact Registry | cleanup policy (conserva 5 versiones) | Sin esto, cada build acumula una imagen más sin límite. |
| Lifecycle del bucket | borra versiones viejas a los 30 días | Margen amplio para deshacer un error de borrado/edición. |

**Trade-off que sí existe:** con `min-instances=0`, la primera visita después de un rato sin uso tiene un arranque en frío (típicamente 1–3 segundos en un contenedor Python pequeño como este). `--cpu-boost` lo reduce, pero no lo elimina — es el costo inherente de no pagar por una instancia siempre encendida. Si en algún momento el cliente reporta que ese delay inicial molesta, la única forma de eliminarlo del todo es subir `min-instances` a `1`, lo cual sí implica una instancia facturándose de forma continua.

## Aplicar estos cambios si ya tenías la infra desplegada

Como el bucket y el Artifact Registry ya existían, no basta con volver a correr `02` y `03` completos la primera vez (ya se corrigió para que sean idempotentes de aquí en adelante). Para aplicar los ajustes de esta ronda sobre recursos ya creados:

```bash
# 1) Cloud Run: reconstruye la imagen (recoge el cambio de gunicorn) y redespliega
./06-build-and-deploy.sh

# 2) Bucket: aplica el lifecycle de 30 días
source 00-variables.sh
cat > /tmp/lifecycle-${BUCKET_NAME}.json <<'EOF'
{"rule": [{"action": {"type": "Delete"}, "condition": {"isLive": false, "daysSinceNoncurrentTime": 30}}]}
EOF
gcloud storage buckets update "gs://${BUCKET_NAME}" --lifecycle-file="/tmp/lifecycle-${BUCKET_NAME}.json"

# 3) Artifact Registry: aplica la política de limpieza
cat > /tmp/ar-cleanup-${AR_REPO}.json <<'EOF'
[
  {"name": "keep-most-recent-5", "action": {"type": "Keep"}, "mostRecentVersions": {"keepCount": 5}},
  {"name": "delete-old-untagged", "action": {"type": "Delete"}, "condition": {"tagState": "UNTAGGED", "olderThan": "604800s"}}
]
EOF
gcloud artifacts repositories set-cleanup-policies "${AR_REPO}" \
  --location="${REGION}" --project="${PROJECT_ID}" --policy="/tmp/ar-cleanup-${AR_REPO}.json"
```

## Posibles siguientes pasos (fuera del alcance de esta demo)

- Cloud Armor / rate limiting frente a Cloud Run.
- Protección CSRF explícita en el callback de login.
- Alertas de presupuesto y cuotas de almacenamiento por cliente.
- VPC Service Controls si el bucket maneja información sensible.
- Registro estructurado (Cloud Logging) de subidas/borrados para auditoría.
