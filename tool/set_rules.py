#!/usr/bin/env python3
"""SafePin: Firestore + Storage セキュリティルールを設定。

匿名投稿(認証なし)を許可する開発向けルール:
  - pins コレクション: 誰でも read/write 可
  - Storage: 誰でも read/write 可(添付アップロード用)

Firebase Rules API を Admin SDK のアクセストークンで呼び出す。
"""
import json

import google.auth.transport.requests
from firebase_admin import credentials
import firebase_admin
import requests

CRED_PATH = "/opt/flutter/firebase-admin-sdk.json"

with open(CRED_PATH) as f:
    _sa = json.load(f)
PROJECT_ID = _sa["project_id"]

FIRESTORE_RULES = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // SafePin: 匿名投稿(認証なし)を許可する開発向けルール
    match /pins/{pinId} {
      allow read, write: if true;
    }
  }
}
"""

STORAGE_RULES = """rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // SafePin: 添付ファイルの匿名アップロードを許可
    match /pins/{pinId}/{fileName} {
      allow read, write: if true;
    }
  }
}
"""


def get_token():
    cred = credentials.Certificate(CRED_PATH)
    scoped = cred.get_credential().with_scopes(
        ["https://www.googleapis.com/auth/cloud-platform",
         "https://www.googleapis.com/auth/firebase"]
    )
    scoped.refresh(google.auth.transport.requests.Request())
    return scoped.token


def create_ruleset(token, rules_content):
    url = f"https://firebaserules.googleapis.com/v1/projects/{PROJECT_ID}/rulesets"
    body = {
        "source": {
            "files": [
                {"name": "rules", "content": rules_content}
            ]
        }
    }
    r = requests.post(url, headers={"Authorization": f"Bearer {token}"}, json=body)
    r.raise_for_status()
    return r.json()["name"]  # projects/.../rulesets/<id>


def release(token, ruleset_name, release_name):
    # 既存リリースがあれば PATCH(update)、なければ POST(create)
    base = f"https://firebaserules.googleapis.com/v1/projects/{PROJECT_ID}/releases"
    full_release = f"projects/{PROJECT_ID}/releases/{release_name}"
    headers = {"Authorization": f"Bearer {token}"}

    # まず update を試みる
    patch_url = f"https://firebaserules.googleapis.com/v1/{full_release}"
    body = {"release": {"name": full_release, "rulesetName": ruleset_name}}
    r = requests.patch(patch_url, headers=headers, json=body)
    if r.status_code == 200:
        return "updated"
    # 無ければ create
    body2 = {"name": full_release, "rulesetName": ruleset_name}
    r2 = requests.post(base, headers=headers, json=body2)
    r2.raise_for_status()
    return "created"


def main():
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(CRED_PATH))
    token = get_token()

    # Firestore ルール
    fs_ruleset = create_ruleset(token, FIRESTORE_RULES)
    fs_action = release(token, fs_ruleset, "cloud.firestore")
    print(f"✅ Firestore ルール {fs_action}: {fs_ruleset}")

    # Storage ルール
    bucket = f"{PROJECT_ID}.firebasestorage.app"
    st_ruleset = create_ruleset(token, STORAGE_RULES)
    try:
        st_action = release(token, st_ruleset, f"firebase.storage/{bucket}")
        print(f"✅ Storage ルール {st_action}: {st_ruleset} (bucket={bucket})")
    except requests.HTTPError as e:
        print(f"⚠️  Storage ルール設定をスキップ(Storage未有効化の可能性): {e}")


if __name__ == "__main__":
    main()
