import { NextRequest, NextResponse } from 'next/server';
import { getMongoDb } from '@/lib/mongodb';

// READ: Fetch raw MongoDB clickstream events
export async function GET(req: NextRequest) {
  try {
    const db = await getMongoDb();
    const coll = db.collection('raw_clickstream_events');

    const platform = req.nextUrl.searchParams.get('platform');
    const limit = parseInt(req.nextUrl.searchParams.get('limit') || '25', 10);

    const filter: Record<string, any> = {};
    if (platform && platform !== 'ALL') {
      filter.platform = platform;
    }

    const events = await coll
      .find(filter)
      .sort({ received_at: -1 })
      .limit(limit)
      .toArray();

    const count = await coll.countDocuments(filter);

    return NextResponse.json({
      success: true,
      data: events,
      totalCount: count,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message },
      { status: 500 }
    );
  }
}

// UPDATE: Modify raw event status / fraud score
export async function PATCH(req: NextRequest) {
  try {
    const db = await getMongoDb();
    const coll = db.collection('raw_clickstream_events');
    const body = await req.json();

    const { session_id, status, bot_score } = body;
    if (!session_id) {
      return NextResponse.json(
        { success: false, error: 'session_id is required' },
        { status: 400 }
      );
    }

    const updateDoc: Record<string, any> = {
      $set: {
        last_reviewed_at: new Date().toISOString(),
      },
    };

    if (status) updateDoc.$set.status = status;
    if (bot_score !== undefined) updateDoc.$set['bot_analysis.confidence_score'] = bot_score;

    const result = await coll.updateOne({ session_id }, updateDoc);

    return NextResponse.json({
      success: true,
      modifiedCount: result.modifiedCount,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message },
      { status: 500 }
    );
  }
}

// DELETE: Delete a raw event
export async function DELETE(req: NextRequest) {
  try {
    const db = await getMongoDb();
    const coll = db.collection('raw_clickstream_events');
    const sessionId = req.nextUrl.searchParams.get('session_id');

    if (!sessionId) {
      return NextResponse.json(
        { success: false, error: 'session_id query param is required' },
        { status: 400 }
      );
    }

    const result = await coll.deleteOne({ session_id: sessionId });

    return NextResponse.json({
      success: true,
      deletedCount: result.deletedCount,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message },
      { status: 500 }
    );
  }
}
