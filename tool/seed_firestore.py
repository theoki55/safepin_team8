#!/usr/bin/env python3
"""SafePin: Firestore にデモデータを投入 + セキュリティルール確認スクリプト。

Flutter の Pin.fromMap() が期待する形状に完全一致させる:
  - type/status/priority/mode は enum の name (小文字文字列)
  - lat/lng は数値
  - createdAt/updatedAt は ISO8601 文字列
  - attachments は空配列
"""
import uuid
from datetime import datetime, timedelta, timezone

import firebase_admin
from firebase_admin import credentials, firestore

CRED_PATH = "/opt/flutter/firebase-admin-sdk.json"
COLLECTION = "pins"

JST = timezone(timedelta(hours=9))


def iso(dt: datetime) -> str:
    # ローカル時刻(JST)の ISO8601。DateTime.tryParse でパース可能。
    return dt.isoformat()


def build_samples():
    now = datetime.now(JST)

    def pin(type_, status, priority, title, comment, lat, lng, author,
            created_min_ago, updated_min_ago):
        created = now - timedelta(minutes=created_min_ago)
        updated = now - timedelta(minutes=updated_min_ago)
        return {
            "id": str(uuid.uuid4()),
            "type": type_,
            "status": status,
            "priority": priority,
            "title": title,
            "comment": comment,
            "lat": lat,
            "lng": lng,
            "authorName": author,
            "mode": "disaster",
            "attachments": [],
            "createdAt": iso(created),
            "updatedAt": iso(updated),
        }

    return [
        pin("need", "unconfirmed", "high",
            "飲料水が不足しています",
            "高齢の母と2人暮らし。備蓄の水が残りわずかです。2Lペットボトルを分けていただけると助かります。",
            35.6820, 139.7660, "丸の内マンション 佐藤", 12, 12),
        pin("need", "confirmed", "medium",
            "スマホの充電をしたい",
            "停電で家族の安否連絡ができません。モバイルバッテリーか充電できる場所を探しています。",
            35.6795, 139.7685, "匿名", 40, 20),
        pin("need", "unconfirmed", "high",
            "常備薬が切れそうです",
            "持病の薬があと1日分しかありません。近くの薬局や医療班の情報があれば教えてください。",
            35.6772, 139.7648, "匿名", 25, 25),
        pin("offer", "unconfirmed", "low",
            "モバイルバッテリー貸せます",
            "大容量バッテリーが3台あります。日中、自宅前でスマホ充電できます。声をかけてください。",
            35.6838, 139.7642, "八重洲 田中", 60, 60),
        pin("offer", "coordinating", "medium",
            "車で物資運搬を手伝えます",
            "軽トラックがあります。ガソリンは半分ほど。近隣への物資運搬をお手伝いできます。",
            35.6760, 139.7700, "京橋 自主防災会", 120, 30),
        pin("offer", "unconfirmed", "low",
            "毛布を分けられます",
            "予備の毛布が5枚あります。寒さで困っている方、取りに来ていただければお渡しします。",
            35.6812, 139.7712, "有楽町 鈴木", 90, 90),
        pin("info", "confirmed", "low",
            "〇〇公園で給水中",
            "午前9時〜午後5時、給水車が来ています。容器を持参してください。",
            35.6805, 139.7620, "地域包括支援センター", 180, 60),
        pin("info", "confirmed", "medium",
            "炊き出しを実施中",
            "本日18時から公民館前で温かいスープを配布します。数に限りあり、お早めに。",
            35.6788, 139.7735, "町内会 炊き出し班", 150, 45),
        pin("info", "resolved", "low",
            "△△通りは通行止め",
            "建物の外壁落下のおそれあり。復旧未定。迂回してください。",
            35.6850, 139.7690, "消防団 第3分団", 300, 120),
        pin("info", "confirmed", "high",
            "避難所に空きがあります",
            "第一小学校の体育館に受け入れ余裕があります。要介護の方も相談可能です。",
            35.6740, 139.7665, "避難所運営委員会", 200, 80),
    ]


def main():
    if not firebase_admin._apps:
        cred = credentials.Certificate(CRED_PATH)
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    col = db.collection(COLLECTION)

    # 既存のデモ(SafePin)データをクリーンにするため、全件チェック
    existing = list(col.limit(1).stream())
    if existing:
        print(f"⚠️  '{COLLECTION}' に既存データあり。既存を残したまま追記します。")

    samples = build_samples()
    batch = db.batch()
    for s in samples:
        ref = col.document(s["id"])
        batch.set(ref, s)
    batch.commit()

    total = len(list(col.stream()))
    print(f"✅ デモデータ {len(samples)} 件を投入しました。")
    print(f"   コレクション '{COLLECTION}' の総ドキュメント数: {total}")


if __name__ == "__main__":
    main()
