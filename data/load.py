#!/usr/bin/env python3
"""
Omnichannel Attribution Engine - Database Loader
Loads generated synthetic CSV datasets into PostgreSQL 16 and raw JSON into MongoDB 7.0.
Computes and populates 384-dimensional dense vectors for ad creatives into pgvector.
"""

import os
import sys
import json
import numpy as np
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
from pymongo import MongoClient

# Database Configuration
PG_HOST = os.getenv("POSTGRES_HOST", "localhost")
PG_PORT = os.getenv("POSTGRES_PORT", "5433")
PG_DB = os.getenv("POSTGRES_DB", "attribution_db")
PG_USER = os.getenv("POSTGRES_USER", "postgres")
PG_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgrespassword")

MONGO_URI = os.getenv(
    "MONGO_URI",
    "mongodb://mongoadmin:mongopassword@localhost:27017/raw_clickstream?authSource=admin"
)

def get_pg_connection():
    return psycopg2.connect(
        host=PG_HOST,
        port=PG_PORT,
        dbname=PG_DB,
        user=PG_USER,
        password=PG_PASSWORD
    )

def generate_mock_embedding(text, dim=384):
    """
    Generate deterministic normalized dense embedding based on text hash.
    Ensures identical text gets identical vector representation.
    """
    np.random.seed(abs(hash(text)) % (2**32))
    vec = np.random.randn(dim).astype(np.float32)
    norm = np.linalg.norm(vec)
    return (vec / norm).tolist()

def load_postgresql(data_dir="data/output"):
    print("[*] Connecting to PostgreSQL...")
    conn = get_pg_connection()
    cur = conn.cursor()

    try:
        # Load dim_date
        print(" -> Loading dim_date...")
        df_date = pd.read_csv(os.path.join(data_dir, "dim_date.csv"))
        records = df_date.to_records(index=False).tolist()
        execute_values(
            cur,
            """
            INSERT INTO dim_date (date_key, full_date, day_of_week, day_name, month_name, month_number, quarter, year, is_weekend)
            VALUES %s ON CONFLICT (date_key) DO NOTHING;
            """,
            records
        )

        # Load dim_user
        print(" -> Loading dim_user...")
        df_user = pd.read_csv(os.path.join(data_dir, "dim_user.csv"))
        records = df_user.to_records(index=False).tolist()
        execute_values(
            cur,
            """
            INSERT INTO dim_user (user_id, email, country, device_preference, first_seen_ts)
            VALUES %s ON CONFLICT (user_id) DO NOTHING;
            """,
            records
        )

        # Load dim_campaign
        print(" -> Loading dim_campaign...")
        df_camp = pd.read_csv(os.path.join(data_dir, "dim_campaign.csv"))
        records = df_camp.to_records(index=False).tolist()
        execute_values(
            cur,
            """
            INSERT INTO dim_campaign (campaign_id, name, channel, is_active, created_at)
            VALUES %s ON CONFLICT (campaign_id) DO NOTHING;
            """,
            records
        )

        # Load dim_paid_campaign
        print(" -> Loading dim_paid_campaign...")
        df_paid = pd.read_csv(os.path.join(data_dir, "dim_paid_campaign.csv"))
        records = df_paid.to_records(index=False).tolist()
        execute_values(
            cur,
            """
            INSERT INTO dim_paid_campaign (campaign_id, cpc_bid, target_network, daily_budget)
            VALUES %s ON CONFLICT (campaign_id) DO NOTHING;
            """,
            records
        )

        # Load dim_email_campaign
        print(" -> Loading dim_email_campaign...")
        df_email = pd.read_csv(os.path.join(data_dir, "dim_email_campaign.csv"))
        records = df_email.to_records(index=False).tolist()
        execute_values(
            cur,
            """
            INSERT INTO dim_email_campaign (campaign_id, sender_domain, template_id, audience_segment)
            VALUES %s ON CONFLICT (campaign_id) DO NOTHING;
            """,
            records
        )

        # Load dim_creative with vector embeddings
        print(" -> Loading dim_creative with 384d pgvector embeddings...")
        df_creat = pd.read_csv(os.path.join(data_dir, "dim_creative.csv"))
        creative_records = []
        for _, row in df_creat.iterrows():
            emb = generate_mock_embedding(row["headline"] + " " + str(row["body_text"]))
            creative_records.append((
                row["creative_id"],
                row["campaign_id"],
                row["headline"],
                row["body_text"],
                row["call_to_action"],
                emb,
                row["created_at"]
            ))
        execute_values(
            cur,
            """
            INSERT INTO dim_creative (creative_id, campaign_id, headline, body_text, call_to_action, embedding, created_at)
            VALUES %s ON CONFLICT (creative_id) DO NOTHING;
            """,
            creative_records
        )

        # Load fact_touchpoint
        print(" -> Loading fact_touchpoint...")
        df_touch = pd.read_csv(os.path.join(data_dir, "fact_touchpoint.csv"))
        records = df_touch.to_records(index=False).tolist()
        execute_values(
            cur,
            """
            INSERT INTO fact_touchpoint (touchpoint_id, user_id, campaign_id, creative_id, event_type, cost, touchpoint_ts)
            VALUES %s ON CONFLICT (user_id, campaign_id, touchpoint_ts) DO NOTHING;
            """,
            records,
            page_size=2000
        )

        # Load fact_conversion
        print(" -> Loading fact_conversion...")
        df_conv = pd.read_csv(os.path.join(data_dir, "fact_conversion.csv"))
        records = df_conv.to_records(index=False).tolist()
        execute_values(
            cur,
            """
            INSERT INTO fact_conversion (conversion_id, user_id, order_id, gross_revenue, net_revenue, currency, conversion_ts, lookback_window_days)
            VALUES %s ON CONFLICT (order_id) DO NOTHING;
            """,
            records
        )

        # Load fact_refund
        print(" -> Loading fact_refund...")
        df_refund = pd.read_csv(os.path.join(data_dir, "fact_refund.csv"))
        if not df_refund.empty:
            records = df_refund.to_records(index=False).tolist()
            execute_values(
                cur,
                """
                INSERT INTO fact_refund (refund_id, conversion_id, refund_amount, refund_ts, reason)
                VALUES %s ON CONFLICT (refund_id) DO NOTHING;
                """,
                records
            )

        # Load fact_spend
        print(" -> Loading fact_spend...")
        df_spend = pd.read_csv(os.path.join(data_dir, "fact_spend.csv"))
        records = df_spend.to_records(index=False).tolist()
        execute_values(
            cur,
            """
            INSERT INTO fact_spend (spend_id, campaign_id, spend_date, amount)
            VALUES %s ON CONFLICT (campaign_id, spend_date) DO NOTHING;
            """,
            records,
            page_size=2000
        )

        conn.commit()
        print("[✓] PostgreSQL warehouse populated successfully!")

    except Exception as e:
        conn.rollback()
        print(f"[!] Error loading PostgreSQL: {e}")
        raise e
    finally:
        cur.close()
        conn.close()

def load_mongodb(data_dir="data/output"):
    print("[*] Connecting to MongoDB...")
    client = MongoClient(MONGO_URI)
    db = client["raw_clickstream"]
    coll = db["raw_clickstream_events"]

    json_path = os.path.join(data_dir, "raw_clickstream.json")
    if not os.path.exists(json_path):
        print(f"[!] Missing {json_path}")
        return

    with open(json_path, "r") as f:
        events = json.load(f)

    # Clean existing for fresh load
    coll.delete_many({})
    if events:
        coll.insert_many(events)
        coll.create_index([("session_id", 1)])
        coll.create_index([("received_at", -1)])
        coll.create_index([("platform", 1)])
        print(f"[✓] Loaded {len(events)} events into MongoDB collection: raw_clickstream_events")

def main():
    data_dir = sys.argv[1] if len(sys.argv) > 1 else "data/output"
    print("=========================================================")
    print("Omnichannel Attribution Engine - Database Loader")
    print(f"Reading CSV & JSON files from: {data_dir}")
    print("=========================================================")
    load_postgresql(data_dir)
    load_mongodb(data_dir)
    print("=========================================================")
    print("[✓] All database loads completed successfully!")
    print("=========================================================")

if __name__ == "__main__":
    main()
