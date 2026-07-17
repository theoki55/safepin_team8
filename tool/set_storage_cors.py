from google.cloud import storage
from google.oauth2 import service_account
import json

KEY = "/opt/flutter/firebase-admin-sdk.json"
with open(KEY) as f:
    project_id = json.load(f)["project_id"]

creds = service_account.Credentials.from_service_account_file(KEY)
client = storage.Client(project=project_id, credentials=creds)

cors_rules = [
    {
        "origin": ["*"],
        "method": ["GET", "HEAD"],
        "responseHeader": ["Content-Type", "Access-Control-Allow-Origin"],
        "maxAgeSeconds": 3600,
    }
]

# firebasestorage.app と appspot.com の両方を試す
candidates = [
    f"{project_id}.firebasestorage.app",
    f"{project_id}.appspot.com",
]

for name in candidates:
    try:
        bucket = client.get_bucket(name)
        bucket.cors = cors_rules
        bucket.patch()
        print(f"OK: CORS set on bucket '{name}'")
        print("  current cors:", bucket.cors)
    except Exception as e:
        print(f"SKIP '{name}': {type(e).__name__}: {e}")
