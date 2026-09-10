import os

import pytest

os.environ.setdefault("FLASK_SECRET_KEY", "test-secret")
os.environ.setdefault("GOOGLE_CLIENT_ID", "test-client-id")
os.environ.setdefault("BUCKET_NAME", "test-bucket")
os.environ.setdefault("GCP_PROJECT_ID", "test-project")

from src import create_app  # noqa: E402


@pytest.fixture()
def app():
    return create_app()


@pytest.fixture()
def client(app):
    return app.test_client()
