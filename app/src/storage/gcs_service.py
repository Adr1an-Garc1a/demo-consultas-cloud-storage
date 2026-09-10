"""Encapsula toda la interacción con Cloud Storage.

Las subidas y descargas de contenido de archivos NO pasan por este backend:
se usan Signed URLs (V4) para que el navegador hable directo con GCS. Así
Cloud Run nunca carga el contenido de un archivo grande en su propia
memoria; solo emite URLs temporales firmadas.

La firma se genera vía la API de IAM Credentials (signBlob) usando las
credenciales por defecto del contenedor (la Service Account adjunta a Cloud
Run), sin necesidad de exportar ni almacenar ninguna llave privada.
"""

import datetime

import google.auth
from google.auth.transport import requests as google_requests
from google.cloud import storage


class GCSService:
    def __init__(self, bucket_name: str, signed_url_minutes: int = 15):
        self._client = storage.Client()
        self._bucket = self._client.bucket(bucket_name)
        self._signed_url_minutes = signed_url_minutes

    def list_files(self) -> list[dict]:
        blobs = self._client.list_blobs(self._bucket.name)
        return [
            {
                "name": blob.name,
                "size": blob.size,
                "updated": blob.updated.isoformat() if blob.updated else None,
                "content_type": blob.content_type,
            }
            for blob in blobs
        ]

    def delete_file(self, filename: str) -> None:
        self._bucket.blob(filename).delete()

    def generate_upload_url(self, filename: str, content_type: str) -> str:
        return self._signed_url(filename, method="PUT", content_type=content_type)

    def generate_download_url(self, filename: str) -> str:
        return self._signed_url(filename, method="GET")

    def _signed_url(self, filename: str, method: str, content_type: str | None = None) -> str:
        credentials, _ = google.auth.default()
        credentials.refresh(google_requests.Request())

        blob = self._bucket.blob(filename)
        kwargs = dict(
            version="v4",
            expiration=datetime.timedelta(minutes=self._signed_url_minutes),
            method=method,
            service_account_email=credentials.service_account_email,
            access_token=credentials.token,
        )
        if content_type:
            kwargs["content_type"] = content_type

        return blob.generate_signed_url(**kwargs)
