import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/pg';

export async function GET(req: NextRequest) {
  try {
    const role = (req.nextUrl.searchParams.get('role') || 'analyst') as 'analyst' | 'manager';

    // Queries the Recursive CTE journey view
    const result = await query(
      `
      SELECT 
        full_journey_path,
        COUNT(*) AS journey_frequency,
        ROUND(AVG(total_touchpoints), 1) AS avg_touchpoints
      FROM view_customer_journey_paths
      GROUP BY full_journey_path
      ORDER BY journey_frequency DESC
      LIMIT 15;
      `,
      [],
      role
    );

    return NextResponse.json({
      success: true,
      data: result.rows,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message },
      { status: 500 }
    );
  }
}
