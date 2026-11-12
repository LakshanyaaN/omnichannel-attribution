import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/pg';

export async function GET(req: NextRequest) {
  try {
    const role = (req.nextUrl.searchParams.get('role') || 'analyst') as 'analyst' | 'manager';

    // Query the Materialized View
    const result = await query(
      `
      SELECT 
        channel,
        total_spend::numeric,
        total_attributed_conversions::int,
        revenue_first_touch::numeric,
        roas_first_touch::numeric,
        revenue_last_touch::numeric,
        roas_last_touch::numeric,
        revenue_linear::numeric,
        roas_linear::numeric,
        revenue_time_decay::numeric,
        roas_time_decay::numeric
      FROM mv_channel_roas_comparison
      ORDER BY total_spend DESC;
      `,
      [],
      role
    );

    // Summary totals
    const totals = result.rows.reduce(
      (acc, row) => ({
        spend: acc.spend + parseFloat(row.total_spend || 0),
        conversions: acc.conversions + parseInt(row.total_attributed_conversions || 0, 10),
        revenue_last_touch: acc.revenue_last_touch + parseFloat(row.revenue_last_touch || 0),
        revenue_time_decay: acc.revenue_time_decay + parseFloat(row.revenue_time_decay || 0),
      }),
      { spend: 0, conversions: 0, revenue_last_touch: 0, revenue_time_decay: 0 }
    );

    return NextResponse.json({
      success: true,
      data: result.rows,
      totals,
      roleUsed: role,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message, code: err.code },
      { status: 500 }
    );
  }
}
