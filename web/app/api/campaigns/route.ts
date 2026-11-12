import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/pg';

export async function GET(req: NextRequest) {
  try {
    const role = (req.nextUrl.searchParams.get('role') || 'analyst') as 'analyst' | 'manager';

    const result = await query(
      `
      SELECT 
        c.campaign_id,
        c.name,
        c.channel,
        c.is_active,
        p.cpc_bid,
        p.target_network,
        p.daily_budget
      FROM dim_campaign c
      LEFT JOIN dim_paid_campaign p ON c.campaign_id = p.campaign_id
      ORDER BY c.created_at DESC;
      `,
      [],
      role
    );

    return NextResponse.json({ success: true, data: result.rows, roleUsed: role });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message, code: err.code },
      { status: 500 }
    );
  }
}

// POST: Create Campaign (Allowed for Manager, BLOCKED by PostgreSQL for Analyst)
export async function POST(req: NextRequest) {
  try {
    const role = (req.nextUrl.searchParams.get('role') || 'analyst') as 'analyst' | 'manager';
    const body = await req.json();
    const { name, channel, cpc_bid, target_network, daily_budget } = body;

    // Database-level permission check:
    // If role is 'analyst', PostgreSQL will directly throw error 42501 (insufficient_privilege)
    const campResult = await query(
      `
      INSERT INTO dim_campaign (name, channel, is_active)
      VALUES ($1, $2, TRUE)
      RETURNING campaign_id;
      `,
      [name, channel],
      role
    );

    const newCampId = campResult.rows[0].campaign_id;

    if (channel !== 'Email') {
      await query(
        `
        INSERT INTO dim_paid_campaign (campaign_id, cpc_bid, target_network, daily_budget)
        VALUES ($1, $2, $3, $4);
        `,
        [newCampId, cpc_bid || 1.5, target_network || 'Default Network', daily_budget || 500.0],
        role
      );
    }

    return NextResponse.json({
      success: true,
      campaign_id: newCampId,
      message: `Campaign '${name}' created successfully by role '${role}'`,
    });
  } catch (err: any) {
    // Catch database permission denied error
    const isPermissionDenied = err.code === '42501' || err.message?.includes('permission denied');
    return NextResponse.json(
      {
        success: false,
        error: err.message,
        isPermissionDenied,
        detail: isPermissionDenied
          ? `DATABASE-ENFORCED RBAC: Role '${req.nextUrl.searchParams.get('role')}' does not have INSERT privileges on dim_campaign.`
          : err.detail,
      },
      { status: isPermissionDenied ? 403 : 500 }
    );
  }
}

// PATCH: Update Campaign Daily Budget (Triggers budget audit log!)
export async function PATCH(req: NextRequest) {
  try {
    const role = (req.nextUrl.searchParams.get('role') || 'analyst') as 'analyst' | 'manager';
    const body = await req.json();
    const { campaign_id, daily_budget } = body;

    // Database-level permission check:
    await query(
      `
      UPDATE dim_paid_campaign
      SET daily_budget = $1
      WHERE campaign_id = $2;
      `,
      [daily_budget, campaign_id],
      role
    );

    return NextResponse.json({
      success: true,
      message: `Daily budget updated to $${daily_budget} by role '${role}' (Triggered audit log in PostgreSQL)`,
    });
  } catch (err: any) {
    const isPermissionDenied = err.code === '42501' || err.message?.includes('permission denied');
    return NextResponse.json(
      {
        success: false,
        error: err.message,
        isPermissionDenied,
        detail: isPermissionDenied
          ? `DATABASE-ENFORCED RBAC: Role '${req.nextUrl.searchParams.get('role')}' does not have UPDATE privileges on dim_paid_campaign.`
          : err.detail,
      },
      { status: isPermissionDenied ? 403 : 500 }
    );
  }
}
