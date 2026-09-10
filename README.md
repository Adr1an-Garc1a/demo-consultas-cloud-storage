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

### CI/CD desde GitHub (opcional pero recomendado)

1. Sube este repo a GitHub.
2. En la consola: **Cloud Build → Repositorios → Conectar repositorio →
   GitHub**, autoriza la GitHub App y selecciona el repo (paso único,
   requiere navegador).
3. Edita `infra/07-cloud-build-trigger.sh` con tu usuario/repo de GitHub y
   ejecútalo:

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

## Posibles siguientes pasos (fuera del alcance de esta demo)

- Cloud Armor / rate limiting frente a Cloud Run.
- Protección CSRF explícita en el callback de login.
- Alertas de presupuesto y cuotas de almacenamiento por cliente.
- VPC Service Controls si el bucket maneja información sensible.
- Registro estructurado (Cloud Logging) de subidas/borrados para auditoría.
