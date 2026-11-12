#!/usr/bin/env python3
"""
Omnichannel Attribution Engine - Synthetic Data Generator
Generates realistic multi-touch customer journeys across Google, Meta, TikTok, and Email.
Supports Baseline and AI-Search Market Shift scenarios.
"""

import os
import sys
import uuid
import random
import argparse
from datetime import datetime, timedelta, date
import json
import numpy as np
import pandas as pd
from faker import Faker

fake = Faker()
Faker.seed(42)
random.seed(42)
np.random.seed(42)

# Channels and their typical distribution
CHANNELS = ["Google", "Meta", "TikTok", "Email"]
TARGET_NETWORKS = {
    "Google": ["Search Ads", "YouTube TrueView", "Performance Max"],
    "Meta": ["Instagram Reels", "Facebook Feed", "Instagram Stories"],
    "TikTok": ["For You Page In-Feed", "TopView Brand Takeover"],
    "Email": ["Promotional Newsletter", "Abandon Cart Flow", "Loyalty Rewards"]
}

CREATIVE_TEMPLATES = {
    "Google": [
        ("Compare Best Enterprise Analytics Tools in 2026", "Evaluate pricing, features, and database integration. Free trial available.", "Start Free Trial"),
        ("Top Rated Marketing Attribution Platform", "Measure ROAS with precision across Google, Meta and TikTok. Get a demo today.", "Request Demo"),
        ("Real-time Clickstream Data Warehouse", "Stop wasting 30% of your ad spend. Modern attribution built for fast teams.", "Learn More")
    ],
    "Meta": [
        ("Stop Guessing Which Ads Drive Real Revenue", "See every touchpoint from first click to purchase with time-decay attribution.", "Try It Now"),
        ("Is Last-Click Attribution Burning Your Ad Budget?", "Discover how top DTC brands scale their Meta ROAS by 40% with multi-touch attribution.", "Watch Video"),
        ("See the Complete Customer Journey in 1 Dashboard", "Real-time visibility across all paid channels and email flows.", "Get Started")
    ],
    "TikTok": [
        ("Why Your Last-Click ROAS is Lying to You", "Check out how this algorithm splits credit across every touchpoint seamlessly.", "See How"),
        ("The Secret to Scaling Ad Spend in 2026", "Stop cutting upper-funnel ads that actually drive conversions.", "Learn More"),
        ("From FYP to Checkout in 3 Days", "Track fast-moving viral campaigns with real-time attribution data.", "Shop Now")
    ],
    "Email": [
        ("Exclusive Product Launch: Early Access Inside", "Thank you for being a valued subscriber. Enjoy 25% off your next order.", "Claim Discount"),
        ("Still Thinking It Over? Your Cart Is Waiting", "Complete your checkout today and receive complimentary expedited shipping.", "Complete Order"),
        ("Weekly Insights: Maximizing Your Return on Ad Spend", "Expert tips on budget allocation across paid search and social.", "Read Report")
    ]
}

def generate_date_dimension(start_date=date(2026, 1, 1), end_date=date(2026, 12, 31)):
    """Generate static date dimension rows for 2026."""
    dates = []
    curr = start_date
    while curr <= end_date:
        dates.append({
            "date_key": int(curr.strftime("%Y%m%d")),
            "full_date": curr.isoformat(),
            "day_of_week": curr.isoweekday(),
            "day_name": curr.strftime("%A"),
            "month_name": curr.strftime("%B"),
            "month_number": curr.month,
            "quarter": (curr.month - 1) // 3 + 1,
            "year": curr.year,
            "is_weekend": curr.isoweekday() in [6, 7]
        })
        curr += timedelta(days=1)
    return pd.DataFrame(dates)

def generate_campaigns_and_creatives():
    """Generate campaign superclasses, subclasses, and ad creatives."""
    campaigns = []
    paid_campaigns = []
    email_campaigns = []
    creatives = []

    for channel in CHANNELS:
        for idx in range(1, 4):  # 3 campaigns per channel = 12 campaigns total
            camp_id = str(uuid.uuid4())
            name = f"{channel} - Campaign {idx}: {'Growth' if idx==1 else 'Retention' if idx==2 else 'Brand Awareness'}"
            created_at = (datetime(2026, 1, 1) + timedelta(days=idx * 5)).isoformat()
            
            campaigns.append({
                "campaign_id": camp_id,
                "name": name,
                "channel": channel,
                "is_active": True,
                "created_at": created_at
            })

            if channel in ["Google", "Meta", "TikTok"]:
                paid_campaigns.append({
                    "campaign_id": camp_id,
                    "cpc_bid": round(random.uniform(0.80, 4.50), 4),
                    "target_network": random.choice(TARGET_NETWORKS[channel]),
                    "daily_budget": round(random.uniform(300.0, 1500.0), 2)
                })
            else:
                email_campaigns.append({
                    "campaign_id": camp_id,
                    "sender_domain": "news.attribution-analytics.com",
                    "template_id": f"tmpl_{fake.bothify(text='??_###')}",
                    "audience_segment": random.choice(["HIGH_LTV", "NEW_SIGNUPS", "WIN_BACK", "ALL"])
                })

            # Create 2-3 creatives per campaign
            templates = CREATIVE_TEMPLATES[channel]
            for c_idx, (headline, body, cta) in enumerate(templates):
                c_id = str(uuid.uuid4())
                creatives.append({
                    "creative_id": c_id,
                    "campaign_id": camp_id,
                    "headline": headline,
                    "body_text": body,
                    "call_to_action": cta,
                    "created_at": created_at
                })

    return (
        pd.DataFrame(campaigns),
        pd.DataFrame(paid_campaigns),
        pd.DataFrame(email_campaigns),
        pd.DataFrame(creatives)
    )

def generate_customer_journeys(num_users, df_creatives, df_campaigns, scenario="baseline"):
    """
    Simulate user journeys, touchpoints, conversions, refunds, and raw MongoDB events.
    Scenario 'ai_shift': After 2026-04-01, Google click volume drops by 30%, Meta/Email rises.
    """
    users = []
    touchpoints = []
    conversions = []
    refunds = []
    raw_mongo_events = []

    # Fast lookup for creative -> campaign & channel
    creative_lookup = {}
    for _, row in df_creatives.iterrows():
        c_id = row["creative_id"]
        camp_id = row["campaign_id"]
        chan = df_campaigns.loc[df_campaigns["campaign_id"] == camp_id, "channel"].values[0]
        creative_lookup[c_id] = (camp_id, chan)

    creative_ids = list(creative_lookup.keys())
    shift_date = datetime(2026, 4, 1)

    print(f"[*] Generating journeys for {num_users} users (Scenario: {scenario})...")

    for i in range(num_users):
        user_id = str(uuid.uuid4())
        first_seen = datetime(2026, 1, 1) + timedelta(seconds=random.randint(0, 300 * 86400))
        users.append({
            "user_id": user_id,
            "email": f"customer_{i}_{fake.unique.user_name()}@{fake.free_email_domain()}",
            "country": random.choice(["USA", "GBR", "CAN", "DEU", "IND", "AUS"]),
            "device_preference": random.choice(["MOBILE", "MOBILE", "DESKTOP", "TABLET"]),
            "first_seen_ts": first_seen.isoformat()
        })

        # Probability of converting
        converts = random.random() < 0.28  # 28% conversion rate overall
        num_touches = random.randint(1, 5) if not converts else random.randint(2, 6)
        
        current_ts = first_seen
        user_touchpoints = []

        for _ in range(num_touches):
            # Advance time between touches (1 hour to 5 days)
            current_ts += timedelta(seconds=random.randint(3600, 5 * 86400))
            if current_ts > datetime(2026, 12, 31):
                break

            # Channel weighting based on scenario
            if scenario == "ai_shift" and current_ts >= shift_date:
                # Meta & Email gain share; Google drops
                channel_weights = [0.15, 0.40, 0.25, 0.20]  # Google, Meta, TikTok, Email
            else:
                channel_weights = [0.35, 0.30, 0.20, 0.15]  # Baseline

            chosen_channel = random.choices(CHANNELS, weights=channel_weights, k=1)[0]
            valid_creatives = [cid for cid, (_, chan) in creative_lookup.items() if chan == chosen_channel]
            chosen_creative = random.choice(valid_creatives)
            chosen_campaign = creative_lookup[chosen_creative][0]

            event_type = random.choices(["CLICK", "IMPRESSION"], weights=[0.8, 0.2], k=1)[0]
            cost = round(random.uniform(0.50, 3.50), 4) if event_type == "CLICK" else 0.0050

            tp_id = str(uuid.uuid4())
            tp_record = {
                "touchpoint_id": tp_id,
                "user_id": user_id,
                "campaign_id": chosen_campaign,
                "creative_id": chosen_creative,
                "event_type": event_type,
                "cost": cost,
                "touchpoint_ts": current_ts.isoformat()
            }
            touchpoints.append(tp_record)
            user_touchpoints.append(tp_record)

            # Raw MongoDB event (contains unparsed UTM tags and nested client metadata)
            raw_mongo_events.append({
                "session_id": f"sess_{uuid.uuid4().hex[:12]}",
                "user_id": user_id,
                "platform": chosen_channel,
                "event_type": event_type,
                "cost": cost,
                "timestamp": current_ts.isoformat(),
                "payload": {
                    "ip": fake.ipv4(),
                    "user_agent": fake.user_agent(),
                    "utm_source": chosen_channel.lower(),
                    "utm_campaign": chosen_campaign,
                    "utm_content": chosen_creative,
                    "device": random.choice(["iOS", "Android", "Windows", "macOS"])
                },
                "processed": True,
                "received_at": current_ts.isoformat()
            })

        # Generate conversion if user converted and had at least one click touchpoint
        clicks = [t for t in user_touchpoints if t["event_type"] == "CLICK"]
        if converts and clicks:
            conv_ts = datetime.fromisoformat(clicks[-1]["touchpoint_ts"]) + timedelta(seconds=random.randint(300, 36 * 3600))
            if conv_ts <= datetime(2026, 12, 31):
                gross_rev = round(random.uniform(45.0, 480.0), 2)
                conv_id = str(uuid.uuid4())
                order_id = f"ORD-{fake.unique.bothify(text='????-########').upper()}"

                # 8% refund probability
                has_refund = random.random() < 0.08
                refund_amt = round(random.uniform(20.0, gross_rev), 2) if has_refund else 0.0
                net_rev = round(gross_rev - refund_amt, 2)

                conversions.append({
                    "conversion_id": conv_id,
                    "user_id": user_id,
                    "order_id": order_id,
                    "gross_revenue": gross_rev,
                    "net_revenue": net_rev,
                    "currency": "USD",
                    "conversion_ts": conv_ts.isoformat(),
                    "lookback_window_days": 30
                })

                if has_refund:
                    refund_ts = conv_ts + timedelta(days=random.randint(1, 14))
                    refunds.append({
                        "refund_id": str(uuid.uuid4()),
                        "conversion_id": conv_id,
                        "refund_amount": refund_amt,
                        "refund_ts": refund_ts.isoformat(),
                        "reason": random.choice(["WRONG_SIZE", "DEFECTIVE", "NOT_AS_DESCRIBED", "BUYER_REMORSE"])
                    })

    return (
        pd.DataFrame(users),
        pd.DataFrame(touchpoints),
        pd.DataFrame(conversions),
        pd.DataFrame(refunds),
        raw_mongo_events
    )

def generate_daily_spend(df_campaigns, start_date=date(2026, 1, 1), end_date=date(2026, 12, 31)):
    """Generate daily aggregate spend for each active campaign."""
    spends = []
    curr = start_date
    while curr <= end_date:
        for _, camp in df_campaigns.iterrows():
            cid = camp["campaign_id"]
            chan = camp["channel"]
            base = 250.0 if chan in ["Google", "Meta"] else 120.0 if chan == "TikTok" else 45.0
            daily_amount = round(base * random.uniform(0.7, 1.4), 2)
            spends.append({
                "spend_id": str(uuid.uuid4()),
                "campaign_id": cid,
                "spend_date": curr.isoformat(),
                "amount": daily_amount
            })
        curr += timedelta(days=1)
    return pd.DataFrame(spends)

def main():
    parser = argparse.ArgumentParser(description="Generate Attribution Engine Synthetic Data")
    parser.add_argument("--scale", choices=["small", "large"], default="small", help="Dataset size scale")
    parser.add_argument("--scenario", choices=["baseline", "ai_shift"], default="ai_shift", help="Market scenario")
    parser.add_argument("--outdir", default="data/output", help="Output directory for CSVs")
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    num_users = 4000 if args.scale == "small" else 40000

    print("=========================================================")
    print(f"Omnichannel Attribution Engine - Generator")
    print(f"Scale: {args.scale} ({num_users} users)")
    print(f"Scenario: {args.scenario}")
    print(f"Output Directory: {args.outdir}")
    print("=========================================================")

    # 1. Date Dimension
    df_date = generate_date_dimension()
    df_date.to_csv(os.path.join(args.outdir, "dim_date.csv"), index=False)
    print(f"[✓] Generated dim_date: {len(df_date)} rows")

    # 2. Campaigns & Creatives
    df_camp, df_paid, df_email, df_creat = generate_campaigns_and_creatives()
    df_camp.to_csv(os.path.join(args.outdir, "dim_campaign.csv"), index=False)
    df_paid.to_csv(os.path.join(args.outdir, "dim_paid_campaign.csv"), index=False)
    df_email.to_csv(os.path.join(args.outdir, "dim_email_campaign.csv"), index=False)
    df_creat.to_csv(os.path.join(args.outdir, "dim_creative.csv"), index=False)
    print(f"[✓] Generated campaigns ({len(df_camp)}) & creatives ({len(df_creat)})")

    # 3. Journeys, Touchpoints, Conversions, Refunds, MongoDB Events
    df_user, df_touch, df_conv, df_refund, raw_mongo = generate_customer_journeys(
        num_users, df_creat, df_camp, scenario=args.scenario
    )
    df_user.to_csv(os.path.join(args.outdir, "dim_user.csv"), index=False)
    df_touch.to_csv(os.path.join(args.outdir, "fact_touchpoint.csv"), index=False)
    df_conv.to_csv(os.path.join(args.outdir, "fact_conversion.csv"), index=False)
    df_refund.to_csv(os.path.join(args.outdir, "fact_refund.csv"), index=False)
    print(f"[✓] Generated dim_user: {len(df_user)} rows")
    print(f"[✓] Generated fact_touchpoint: {len(df_touch)} rows")
    print(f"[✓] Generated fact_conversion: {len(df_conv)} rows")
    print(f"[✓] Generated fact_refund: {len(df_refund)} rows")

    # 4. Daily Spend
    df_spend = generate_daily_spend(df_camp)
    df_spend.to_csv(os.path.join(args.outdir, "fact_spend.csv"), index=False)
    print(f"[✓] Generated fact_spend: {len(df_spend)} rows")

    # 5. Raw Clickstream JSON for MongoDB
    mongo_file = os.path.join(args.outdir, "raw_clickstream.json")
    with open(mongo_file, "w") as f:
        json.dump(raw_mongo, f, indent=2)
    print(f"[✓] Saved MongoDB raw events: {len(raw_mongo)} records -> {mongo_file}")

    print("=========================================================")
    print("[✓] All synthetic datasets generated successfully!")
    print("=========================================================")

if __name__ == "__main__":
    main()
