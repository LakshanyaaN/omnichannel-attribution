#!/usr/bin/env python3
"""
Omnichannel Attribution Engine - Concurrency Control & Row-Locking Test
Demonstrates Unit 4 Transaction Mechanics:
- Simulates 5 simultaneous worker threads competing to deduct advertising budget
- Uses PostgreSQL Pessimistic Row-Level Locking (SELECT ... FOR UPDATE)
- Guarantees zero lost updates, zero race conditions, and perfect balance consistency
"""

import os
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
import psycopg2

# Database Connection Configurations
PG_HOST = os.getenv("POSTGRES_HOST", "localhost")
PG_PORT = os.getenv("POSTGRES_PORT", "5433")
PG_DB = os.getenv("POSTGRES_DB", "attribution_db")
PG_USER = os.getenv("POSTGRES_USER", "postgres")
PG_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgrespassword")

def get_connection():
    return psycopg2.connect(
        host=PG_HOST,
        port=PG_PORT,
        dbname=PG_DB,
        user=PG_USER,
        password=PG_PASSWORD
    )

def setup_test_campaign():
    """Create a dedicated test campaign with an exact starting budget of $500.00."""
    conn = get_connection()
    cur = conn.cursor()
    test_id = str(uuid.uuid4())
    camp_name = f"Concurrency Test Campaign - {test_id[:8]}"

    cur.execute("""
        INSERT INTO dim_campaign (campaign_id, name, channel, is_active)
        VALUES (%s, %s, 'Google', TRUE);
    """, (test_id, camp_name))

    cur.execute("""
        INSERT INTO dim_paid_campaign (campaign_id, cpc_bid, target_network, daily_budget)
        VALUES (%s, 2.50, 'Search Concurrency', 500.00);
    """, (test_id,))

    conn.commit()
    cur.close()
    conn.close()
    return test_id, camp_name

def deduct_budget_worker(thread_id, campaign_id, deduction_amount=150.00):
    """
    Simulates a worker thread executing an atomic spend deduction using SELECT ... FOR UPDATE.
    """
    conn = get_connection()
    cur = conn.cursor()
    result = {"thread_id": thread_id, "success": False, "message": "", "remaining_budget": None}

    try:
        # Start Transaction
        cur.execute("BEGIN;")

        # Acquire exclusive row-level lock on the target campaign
        cur.execute("""
            SELECT daily_budget 
            FROM dim_paid_campaign 
            WHERE campaign_id = %s 
            FOR UPDATE;
        """, (campaign_id,))
        
        row = cur.fetchone()
        if not row:
            raise Exception("Campaign not found")
        
        current_budget = float(row[0])

        # Artificial micro-sleep to accentuate race conditions if locking were absent
        time.sleep(0.05)

        # Check budget availability
        if current_budget >= deduction_amount:
            new_budget = current_budget - deduction_amount
            cur.execute("""
                UPDATE dim_paid_campaign 
                SET daily_budget = %s 
                WHERE campaign_id = %s;
            """, (new_budget, campaign_id))
            
            conn.commit()
            result["success"] = True
            result["message"] = f"Deducted ${deduction_amount:.2f}. Balance: ${new_budget:.2f}"
            result["remaining_budget"] = new_budget
        else:
            conn.rollback()
            result["success"] = False
            result["message"] = f"REJECTED: Insufficient budget (Available: ${current_budget:.2f}, Required: ${deduction_amount:.2f})"
            result["remaining_budget"] = current_budget

    except Exception as e:
        conn.rollback()
        result["success"] = False
        result["message"] = f"ERROR: {str(e)}"
    finally:
        cur.close()
        conn.close()

    return result

def cleanup_test_campaign(campaign_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM dim_campaign WHERE campaign_id = %s;", (campaign_id,))
    conn.commit()
    cur.close()
    conn.close()

def main():
    print("=" * 70)
    print(" Omnichannel Attribution Engine - Concurrency & Row-Locking Test")
    print(" Simulating 5 Concurrent Threads with SELECT ... FOR UPDATE")
    print("=" * 70)

    # 1. Setup Campaign with $500.00
    camp_id, camp_name = setup_test_campaign()
    starting_budget = 500.00
    deduction_per_thread = 150.00
    num_threads = 5

    print(f"\n[*] Initialized Test Campaign: '{camp_name}'")
    print(f"[*] Starting Daily Budget:    ${starting_budget:.2f}")
    print(f"[*] Competing Threads:        {num_threads} parallel threads")
    print(f"[*] Deduction per Thread:     ${deduction_per_thread:.2f}")
    print(f"[*] Total Requested Spend:    ${num_threads * deduction_per_thread:.2f} (Exceeds $500 budget!)")
    print("\n[*] Firing parallel threads simultaneously...")

    # 2. Fire concurrent worker threads
    results = []
    start_time = time.time()
    with ThreadPoolExecutor(max_workers=num_threads) as executor:
        futures = [
            executor.submit(deduct_budget_worker, i + 1, camp_id, deduction_per_thread)
            for i in range(num_threads)
        ]
        for f in as_completed(futures):
            results.append(f.result())

    elapsed = time.time() - start_time

    # 3. Analyze Results
    results.sort(key=lambda x: x["thread_id"])
    success_count = sum(1 for r in results if r["success"])
    fail_count = sum(1 for r in results if not r["success"])

    print("\n[+] Thread Execution Results:")
    print("-" * 70)
    for r in results:
        status_symbol = "[✓] APPROVED" if r["success"] else "[✗] DECLINED"
        print(f" Thread #{r['thread_id']} -> {status_symbol:<14} | {r['message']}")

    # 4. Verify Final State in PostgreSQL
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT daily_budget FROM dim_paid_campaign WHERE campaign_id = %s;", (camp_id,))
    final_budget = float(cur.fetchone()[0])
    cur.close()
    conn.close()

    print("-" * 70)
    print(f"[*] Total Execution Time:    {elapsed:.3f} seconds")
    print(f"[*] Successful Transactions: {success_count} ($150.00 x {success_count} = ${success_count * 150:.2f})")
    print(f"[*] Rejected Transactions:   {fail_count}")
    print(f"[*] Final Database Budget:   ${final_budget:.2f}")

    # 5. Assertions
    # 500 - (3 * 150) = 50. Exactly 3 should succeed, 2 should fail.
    assert success_count == 3, f"Expected 3 successes, got {success_count}"
    assert fail_count == 2, f"Expected 2 rejections, got {fail_count}"
    assert abs(final_budget - 50.00) < 0.01, f"Expected $50.00 remaining, got ${final_budget:.2f}"

    print("\n" + "=" * 70)
    print(" [✓] CONCURRENCY & ROW-LOCKING INTEGRITY CHECK PASSED (100% CONSISTENT)!")
    print("     Zero lost updates. Zero negative balance. Clean transaction serialization.")
    print("=" * 70)

    # Cleanup
    cleanup_test_campaign(camp_id)

if __name__ == "__main__":
    main()
