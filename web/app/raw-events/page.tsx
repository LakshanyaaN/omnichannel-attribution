'use client';

import React, { useState, useEffect } from 'react';
import { Database, Trash2, Edit3, RefreshCw, CheckCircle, AlertTriangle } from 'lucide-react';

interface RawEvent {
  _id: string;
  session_id: string;
  platform: string;
  event_type: string;
  cost: number;
  status?: string;
  received_at: string;
  payload?: {
    device?: string;
    ip?: string;
    utm_campaign?: string;
  };
}

export default function RawEventsPage() {
  const [events, setEvents] = useState<RawEvent[]>([]);
  const [platformFilter, setPlatformFilter] = useState('ALL');
  const [loading, setLoading] = useState(true);
  const [feedback, setFeedback] = useState<string | null>(null);

  const fetchEvents = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/raw-events?platform=${platformFilter}&limit=20`);
      const json = await res.json();
      if (json.success) {
        setEvents(json.data);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEvents();
  }, [platformFilter]);

  // UPDATE: Mutate status in MongoDB
  const handleUpdate = async (sessionId: string) => {
    try {
      const res = await fetch('/api/raw-events', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          session_id: sessionId,
          status: 'MANUALLY_AUDITED',
          bot_score: 0.99,
        }),
      });
      const json = await res.json();
      if (json.success) {
        setFeedback(`[UPDATE SUCCESS] Updated session ${sessionId} to status 'MANUALLY_AUDITED'`);
        fetchEvents();
      }
    } catch (err: any) {
      setFeedback(`[UPDATE FAILED] ${err.message}`);
    }
  };

  // DELETE: Delete document from MongoDB
  const handleDelete = async (sessionId: string) => {
    if (!confirm(`Are you sure you want to delete session ${sessionId} from MongoDB?`)) return;

    try {
      const res = await fetch(`/api/raw-events?session_id=${sessionId}`, {
        method: 'DELETE',
      });
      const json = await res.json();
      if (json.success) {
        setFeedback(`[DELETE SUCCESS] Purged session ${sessionId} from MongoDB collection.`);
        setEvents(events.filter((e) => e.session_id !== sessionId));
      }
    } catch (err: any) {
      setFeedback(`[DELETE FAILED] ${err.message}`);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-slate-800 pb-5">
        <div>
          <div className="inline-flex items-center space-x-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 mb-2">
            <Database className="w-3.5 h-3.5" />
            <span>MongoDB 7.0 Staging Store</span>
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">
            Raw Clickstream Event Manager (RUD)
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Demonstrating direct Read, Update, and Delete operations on unstructured NoSQL click telemetry
          </p>
        </div>

        <div className="flex items-center space-x-3 w-full sm:w-auto">
          <select
            value={platformFilter}
            onChange={(e) => setPlatformFilter(e.target.value)}
            className="bg-slate-900 border border-slate-800 rounded-xl px-4 py-2 text-xs text-slate-300 focus:outline-none focus:border-indigo-500 cursor-pointer"
          >
            <option value="ALL">All Platforms</option>
            <option value="Google">Google</option>
            <option value="Meta">Meta</option>
            <option value="TikTok">TikTok</option>
            <option value="Email">Email</option>
          </select>

          <button
            onClick={fetchEvents}
            className="flex items-center space-x-1.5 px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-300 hover:text-white transition"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-emerald-400' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* Live Action Feedback */}
      {feedback && (
        <div className="p-3 bg-emerald-950/40 border border-emerald-800/40 rounded-xl text-xs text-emerald-300 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <CheckCircle className="w-4 h-4 text-emerald-400" />
            <span>{feedback}</span>
          </div>
          <button onClick={() => setFeedback(null)} className="text-slate-400 hover:text-white">✕</button>
        </div>
      )}

      {/* Events Table */}
      <div className="bg-slate-900/60 border border-slate-800 rounded-xl overflow-hidden shadow">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-950 text-xs uppercase text-slate-400 border-b border-slate-800 font-semibold tracking-wider">
              <tr>
                <th className="px-5 py-3.5">Session ID</th>
                <th className="px-5 py-3.5">Platform</th>
                <th className="px-5 py-3.5">Event</th>
                <th className="px-5 py-3.5">Device</th>
                <th className="px-5 py-3.5">Cost</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5 text-right">RUD Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 font-mono text-xs">
              {loading ? (
                <tr>
                  <td colSpan={7} className="px-6 py-8 text-center text-slate-400 font-sans">
                    <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-emerald-400" />
                    Querying MongoDB `raw_clickstream_events` collection...
                  </td>
                </tr>
              ) : events.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-8 text-center text-slate-400 font-sans">
                    No documents found in MongoDB. Run `python data/load.py` to seed.
                  </td>
                </tr>
              ) : (
                events.map((e) => (
                  <tr key={e.session_id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="px-5 py-3.5 text-indigo-300 font-semibold truncate max-w-[140px]">
                      {e.session_id}
                    </td>
                    <td className="px-5 py-3.5">
                      <span className="px-2 py-0.5 rounded text-[10px] uppercase font-sans font-bold bg-slate-800 text-slate-300">
                        {e.platform}
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-slate-300">
                      {e.event_type}
                    </td>
                    <td className="px-5 py-3.5 text-slate-400 font-sans">
                      {e.payload?.device || 'Unknown'}
                    </td>
                    <td className="px-5 py-3.5 text-emerald-400 font-semibold">
                      ${Number(e.cost).toFixed(2)}
                    </td>
                    <td className="px-5 py-3.5">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-sans font-medium ${
                        e.status === 'MANUALLY_AUDITED' 
                          ? 'bg-indigo-950 text-indigo-300 border border-indigo-800' 
                          : 'bg-slate-800 text-slate-400'
                      }`}>
                        {e.status || 'PROCESSED'}
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-right font-sans">
                      <div className="flex items-center justify-end space-x-2">
                        {/* UPDATE button */}
                        <button
                          onClick={() => handleUpdate(e.session_id)}
                          className="p-1.5 rounded-lg bg-slate-800 text-slate-300 hover:text-white hover:bg-indigo-600 transition"
                          title="Update Status in MongoDB"
                        >
                          <Edit3 className="w-3.5 h-3.5" />
                        </button>

                        {/* DELETE button */}
                        <button
                          onClick={() => handleDelete(e.session_id)}
                          className="p-1.5 rounded-lg bg-slate-800 text-slate-300 hover:text-rose-400 hover:bg-rose-950/40 transition"
                          title="Delete Document from MongoDB"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
