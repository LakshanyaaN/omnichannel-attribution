'use client';

import React, { useState, useEffect } from 'react';
import { useRole } from '@/components/Navigation';
import { GitFork, ArrowRight, RefreshCw, Sparkles } from 'lucide-react';

interface Journey {
  full_journey_path: string;
  journey_frequency: number;
  avg_touchpoints: number;
}

const CHANNEL_COLORS: Record<string, string> = {
  Google: 'bg-blue-500/10 text-blue-400 border-blue-500/30',
  Meta: 'bg-indigo-500/10 text-indigo-400 border-indigo-500/30',
  TikTok: 'bg-pink-500/10 text-pink-400 border-pink-500/30',
  Email: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30',
  Conversion: 'bg-amber-500/10 text-amber-300 border-amber-500/30 font-bold',
};

export default function JourneysPage() {
  const { role } = useRole();
  const [journeys, setJourneys] = useState<Journey[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchJourneys = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/journeys?role=${role}`);
      const json = await res.json();
      if (json.success) {
        setJourneys(json.data);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchJourneys();
  }, [role]);

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-slate-800 pb-5">
        <div>
          <div className="inline-flex items-center space-x-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 mb-2">
            <GitFork className="w-3.5 h-3.5" />
            <span>SQL Recursive CTE Traversal</span>
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">
            Customer Journey Paths
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Reconstructed multi-hop touchpoint sequences leading to conversions
          </p>
        </div>

        <button
          onClick={fetchJourneys}
          className="flex items-center space-x-2 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 text-xs text-slate-300 hover:text-white hover:bg-slate-800 transition"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-indigo-400' : ''}`} />
          <span>Refresh Journeys</span>
        </button>
      </div>

      <div className="grid grid-cols-1 gap-3">
        {loading ? (
          <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-12 text-center text-slate-400">
            <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-3 text-indigo-400" />
            Traversing recursive journey graph in PostgreSQL...
          </div>
        ) : journeys.length === 0 ? (
          <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-12 text-center text-slate-400">
            No journey paths available yet.
          </div>
        ) : (
          journeys.map((j, idx) => {
            const steps = j.full_journey_path.split(' -> ');

            return (
              <div
                key={idx}
                className="bg-slate-900/60 border border-slate-800 rounded-xl p-4 flex flex-col md:flex-row items-start md:items-center justify-between gap-4 hover:border-slate-700 transition"
              >
                {/* Visual Step Pills */}
                <div className="flex flex-wrap items-center gap-2">
                  {steps.map((step, sIdx) => {
                    const colorClass = CHANNEL_COLORS[step] || 'bg-slate-800 text-slate-200 border-slate-700';
                    return (
                      <React.Fragment key={sIdx}>
                        <span className={`px-2.5 py-1 rounded-md text-xs border ${colorClass}`}>
                          {step}
                        </span>
                        {sIdx < steps.length - 1 && (
                          <ArrowRight className="w-3.5 h-3.5 text-slate-600" />
                        )}
                      </React.Fragment>
                    );
                  })}
                </div>

                {/* Frequency & Depth Stats */}
                <div className="flex items-center space-x-6 text-xs text-slate-400 font-mono">
                  <div>
                    <span className="text-slate-500">Orders: </span>
                    <strong className="text-white">{j.journey_frequency}</strong>
                  </div>
                  <div>
                    <span className="text-slate-500">Avg Touches: </span>
                    <strong className="text-indigo-400">{j.avg_touchpoints}</strong>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
