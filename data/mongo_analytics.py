#!/usr/bin/env python3
"""
Omnichannel Attribution Engine - MongoDB Clickstream Analytics
Demonstrates Unit 4 Advanced NoSQL Aggregations:
- Multi-stage pipelines ($match, $group, $sort, $project)
- Device & platform volume breakdown
- Anomaly / Bot detection (high frequency clicks per IP)
"""

import os
from pymongo import MongoClient

MONGO_URI = os.getenv(
    "MONGO_URI",
    "mongodb://mongoadmin:mongopassword@localhost:27017/raw_clickstream?authSource=admin"
)

def run_mongo_analytics():
    client = MongoClient(MONGO_URI)
    db = client["raw_clickstream"]
    coll = db["raw_clickstream_events"]

    total_events = coll.count_documents({})
    print("=================================================================")
    print(f" MongoDB Raw Clickstream Analytics (Total Records: {total_events})")
    print("=================================================================")

    # 1. Platform Summary Pipeline
    print("\n[1] Performance Summary by Advertising Platform:")
    print("-" * 65)
    platform_pipeline = [
        {
            "$group": {
                "_id": "$platform",
                "total_events": {"$sum": 1},
                "total_clicks": {
                    "$sum": {"$cond": [{"$eq": ["$event_type", "CLICK"]}, 1, 0]}
                },
                "total_impressions": {
                    "$sum": {"$cond": [{"$eq": ["$event_type", "IMPRESSION"]}, 1, 0]}
                },
                "total_spend": {"$sum": "$cost"},
                "avg_cpc": {"$avg": "$cost"}
            }
        },
        {"$sort": {"total_events": -1}}
    ]
    for p in coll.aggregate(platform_pipeline):
        print(f" * Platform: {p['_id']:<8} | Events: {p['total_events']:<6} | Clicks: {p['total_clicks']:<5} | Spend: ${p['total_spend']:<8.2f} | Avg CPC: ${p['avg_cpc']:.3f}")

    # 2. Device Distribution Pipeline
    print("\n[2] Device Telemetry Distribution:")
    print("-" * 65)
    device_pipeline = [
        {
            "$group": {
                "_id": "$payload.device",
                "count": {"$sum": 1}
            }
        },
        {"$sort": {"count": -1}}
    ]
    for d in coll.aggregate(device_pipeline):
        device = d['_id'] if d['_id'] else 'Unknown'
        percentage = (d['count'] / total_events) * 100
        print(f" * Device: {device:<10} | Count: {d['count']:<6} ({percentage:.1f}%)")

    # 3. Anomaly / Bot Detection Pipeline (High frequency clicks per IP)
    print("\n[3] Click Frequency Anomaly Detection (Top Active IPs):")
    print("-" * 65)
    anomaly_pipeline = [
        {"$match": {"event_type": "CLICK"}},
        {
            "$group": {
                "_id": "$payload.ip",
                "click_count": {"$sum": 1},
                "total_cost": {"$sum": "$cost"}
            }
        },
        {"$match": {"click_count": {"$gt": 1}}},
        {"$sort": {"click_count": -1}},
        {"$limit": 5}
    ]
    anomalies = list(coll.aggregate(anomaly_pipeline))
    if anomalies:
        for a in anomalies:
            print(f" * IP: {a['_id']:<16} | Clicks: {a['click_count']:<3} | Incurred Cost: ${a['total_cost']:.2f}")
    else:
        print(" * No suspicious high-frequency IP clusters detected.")

    print("\n=================================================================")
    print(" [✓] MongoDB Aggregation Analysis Completed Successfully!")
    print("=================================================================")

if __name__ == "__main__":
    run_mongo_analytics()
