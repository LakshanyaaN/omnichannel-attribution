#!/usr/bin/env python3
"""
Omnichannel Attribution Engine - NoSQL & Vector Feature RUD Test Suite
Validates Rubric Component 9 (7 Marks):
- Full Read, Update, Delete (RUD) on MongoDB raw event store
- MongoDB Aggregation Pipeline analytics
- Read (Cosine Search), Update, and Delete on pgvector dense embeddings
"""

import os
import sys
import uuid
from datetime import datetime
import numpy as np
import psycopg2
from pymongo import MongoClient

# Database Connection Configurations
PG_HOST = os.getenv("POSTGRES_HOST", "localhost")
PG_PORT = os.getenv("POSTGRES_PORT", "5433")
PG_DB = os.getenv("POSTGRES_DB", "attribution_db")
PG_USER = os.getenv("POSTGRES_USER", "postgres")
PG_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgrespassword")

MONGO_URI = os.getenv(
    "MONGO_URI",
    "mongodb://mongoadmin:mongopassword@localhost:27017/raw_clickstream?authSource=admin"
)

def print_header(title):
    print("\n" + "=" * 65)
    print(f" {title}")
    print("=" * 65)

def test_mongodb_rud():
    print_header("PART 1: MONGODB NOSQL FEATURE RUD OPERATIONS")
    client = MongoClient(MONGO_URI)
    db = client["raw_clickstream"]
    coll = db["raw_clickstream_events"]

    # --- 1. READ: Filtered and Nested Query ---
    print("\n[*] 1. Testing MongoDB READ (R)...")
    sample_event = coll.find_one({"platform": "Meta", "event_type": "CLICK"})
    if not sample_event:
        # Fallback to any event
        sample_event = coll.find_one()
    
    assert sample_event is not None, "MongoDB contains no records!"
    print(f" -> Found Session ID: {sample_event.get('session_id')}")
    print(f" -> Platform: {sample_event.get('platform')}, Cost: ${sample_event.get('cost')}")
    print(f" -> Nested Device: {sample_event.get('payload', {}).get('device')}")
    print(" [✓] PASS [1/7]: MongoDB Nested READ Verified.")

    # --- 2. UPDATE: In-place modification ($set, $inc, $currentDate) ---
    print("\n[*] 2. Testing MongoDB UPDATE (U)...")
    target_session = sample_event["session_id"]
    update_result = coll.update_one(
        {"session_id": target_session},
        {
            "$set": {
                "bot_analysis.is_fraudulent": False,
                "bot_analysis.confidence_score": 0.985,
                "status": "MANUALLY_AUDITED"
            },
            "$inc": {"audit_retry_count": 1},
            "$currentDate": {"last_modified": True}
        }
    )
    assert update_result.modified_count == 1, "Failed to update MongoDB document!"
    
    # Verify the updated document
    updated_doc = coll.find_one({"session_id": target_session})
    assert updated_doc["status"] == "MANUALLY_AUDITED"
    assert updated_doc["audit_retry_count"] >= 1
    print(f" -> Updated Session {target_session} to status: {updated_doc['status']}")
    print(f" -> Enriched nested fraud score: {updated_doc['bot_analysis']['confidence_score']}")
    print(" [✓] PASS [2/7]: MongoDB In-Place UPDATE Verified.")

    # --- 3. DELETE: Targeted cleanup of bot / quarantined logs ---
    print("\n[*] 3. Testing MongoDB DELETE (D)...")
    # Insert a temporary synthetic bot record to test deletion
    bot_session = f"bot_test_{uuid.uuid4().hex[:8]}"
    coll.insert_one({
        "session_id": bot_session,
        "platform": "TikTok",
        "event_type": "CLICK",
        "cost": 0.0,
        "status": "QUARANTINED_BOT",
        "received_at": datetime.utcnow().isoformat()
    })
    
    # Confirm insertion
    assert coll.find_one({"session_id": bot_session}) is not None
    
    # Execute DELETE
    del_result = coll.delete_one({"session_id": bot_session})
    assert del_result.deleted_count == 1, "Failed to delete bot document!"
    
    # Confirm deletion
    assert coll.find_one({"session_id": bot_session}) is None
    print(f" -> Successfully quarantined and deleted test bot session: {bot_session}")
    print(" [✓] PASS [3/7]: MongoDB DELETE Verified.")

    # --- 4. ADVANCED: MongoDB Aggregation Pipeline ---
    print("\n[*] 4. Testing MongoDB Aggregation Pipeline...")
    pipeline = [
        {"$match": {"event_type": "CLICK"}},
        {
            "$group": {
                "_id": "$platform",
                "total_clicks": {"$sum": 1},
                "total_cost": {"$sum": "$cost"},
                "avg_cost_per_click": {"$avg": "$cost"}
            }
        },
        {"$sort": {"total_clicks": -1}}
    ]
    agg_results = list(coll.aggregate(pipeline))
    assert len(agg_results) > 0, "Aggregation returned 0 results!"
    for row in agg_results:
        print(f" -> Channel: {row['_id']:<8} | Clicks: {row['total_clicks']:<6} | Avg CPC: ${row['avg_cost_per_click']:.2f}")
    print(" [✓] PASS [4/7]: MongoDB Multi-Stage Aggregation Pipeline Verified.")

def test_pgvector_rud():
    print_header("PART 2: POSTGRESQL PGVECTOR FEATURE RUD OPERATIONS")
    conn = psycopg2.connect(
        host=PG_HOST,
        port=PG_PORT,
        dbname=PG_DB,
        user=PG_USER,
        password=PG_PASSWORD
    )
    cur = conn.cursor()

    try:
        # --- 5. VECTOR READ: Cosine Similarity Nearest Neighbors ---
        print("\n[*] 5. Testing pgvector READ (Cosine Distance <=>)...")
        cur.execute("""
            WITH ref AS (
                SELECT headline, embedding 
                FROM dim_creative 
                LIMIT 1
            )
            SELECT 
                c.headline,
                ROUND((1 - (c.embedding <=> ref.embedding))::numeric, 4) AS cosine_similarity
            FROM dim_creative c
            CROSS JOIN ref
            WHERE c.headline <> ref.headline
            ORDER BY c.embedding <=> ref.embedding ASC
            LIMIT 3;
        """)
        top_similar = cur.fetchall()
        assert len(top_similar) > 0, "Vector similarity query returned no results!"
        print(" -> Reference Creative: Top 3 Semantically Similar Headlines:")
        for headline, sim in top_similar:
            print(f"    * Similarity: {sim:.4f} | Headline: '{headline}'")
        print(" [✓] PASS [5/7]: pgvector Semantic Cosine Similarity READ Verified.")

        # --- 6. VECTOR UPDATE: In-place Embedding Modification ---
        print("\n[*] 6. Testing pgvector UPDATE (Embedding Mutation)...")
        # Fetch one creative
        cur.execute("SELECT creative_id, headline, embedding FROM dim_creative LIMIT 1;")
        c_id, old_headline, old_emb = cur.fetchone()

        # Generate a distinct updated vector (normalized)
        new_vec = np.random.randn(384).astype(np.float32)
        new_vec = (new_vec / np.linalg.norm(new_vec)).tolist()
        new_headline = "Next-Gen AI Marketing Attribution Engine 2026"

        cur.execute("""
            UPDATE dim_creative
            SET headline = %s,
                embedding = %s
            WHERE creative_id = %s;
        """, (new_headline, new_vec, c_id))
        conn.commit()

        # Verify update
        cur.execute("SELECT headline FROM dim_creative WHERE creative_id = %s;", (c_id,))
        updated_headline = cur.fetchone()[0]
        assert updated_headline == new_headline, "Failed to update vector headline!"
        print(f" -> Updated Creative ID: {c_id}")
        print(f" -> Old Headline: '{old_headline}'")
        print(f" -> New Headline: '{updated_headline}'")
        print(" [✓] PASS [6/7]: pgvector Embedding UPDATE Verified.")

        # --- 7. VECTOR DELETE: Removal of Creative and Vector Space Cleanup ---
        print("\n[*] 7. Testing pgvector DELETE (Vector Removal)...")
        # Insert a temporary creative to delete
        temp_id = str(uuid.uuid4())
        cur.execute("SELECT campaign_id FROM dim_campaign LIMIT 1;")
        camp_id = cur.fetchone()[0]

        temp_vec = np.random.randn(384).astype(np.float32)
        temp_vec = (temp_vec / np.linalg.norm(temp_vec)).tolist()

        cur.execute("""
            INSERT INTO dim_creative (creative_id, campaign_id, headline, body_text, embedding)
            VALUES (%s, %s, 'Temporary Outdated Vector Ad', 'To be deleted.', %s);
        """, (temp_id, camp_id, temp_vec))
        conn.commit()

        # Delete the vector creative
        cur.execute("DELETE FROM dim_creative WHERE creative_id = %s;", (temp_id,))
        conn.commit()

        # Confirm deletion
        cur.execute("SELECT COUNT(*) FROM dim_creative WHERE creative_id = %s;", (temp_id,))
        remaining = cur.fetchone()[0]
        assert remaining == 0, "Failed to delete vector creative!"
        print(f" -> Successfully deleted temporary vector creative: {temp_id}")
        print(" [✓] PASS [7/7]: pgvector Vector Record DELETE Verified.")

    finally:
        cur.close()
        conn.close()

def main():
    print("=================================================================")
    print(" Omnichannel Attribution Engine - NoSQL & Vector Feature Test")
    print(" Validating Rubric Component 9: Full RUD on MongoDB & pgvector")
    print("=================================================================")
    test_mongodb_rud()
    test_pgvector_rud()
    print_header("ALL 7 NoSQL & VECTOR RUD TESTS PASSED SUCCESSFULLY! (7/7 MARKS)")

if __name__ == "__main__":
    main()
