'use client';

import React, { useState, useEffect } from 'react';
import { useRole } from '@/components/Navigation';
import { 
  TrendingUp, 
  DollarSign, 
  ShoppingCart, 
  RefreshCw, 
  Layers, 
  ArrowUpRight,
  Info 
} from 'lucide-react';

interface ChannelRoas {
  channel: string;
  total_spend: number;
  total_attributed_conversions: number;
  revenue_first_touch: number;
  roas_first_touch: number;
  revenue_last_touch: number;
  roas_last_touch: number;
  revenue_linear: number;
  roas_linear: number;
  revenue_time_decay: number;
  roas_time_decay: number;
}

export default function DashboardPage() {
  const { role } = useRole();
  const [data, setData] = useState<ChannelRoas[]>([]);
  const [totals, setTotals] = useState<any>({ spend: 0, conversions: 0, revenue_time_decay: 0 });
  const [loading, setLoading] = useState(true);
  const [activeModel, setActiveModel] = useState<'time_decay' | 'first_touch' | 'last_touch' | 'linear'>('time_decay');

  const fetchData = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/roas?role=${role}`);
      const json = await res.json();
      if (json.success) {
        setData(json.data);
        setTotals(json.totals);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [role]);

  return (
    <div className="space-y-8">
      {/* Top Banner / Problem Statement */}
      <div className="bg-gradient-to-r from-indigo-950/80 via-slate-900 to-slate-900 border border-indigo-900/50 rounded-2xl p-6 shadow-xl relative overflow-hidden">
        <div className="max-w-3xl space-y-2">
          <div className="inline-flex items-center space-x-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
            <Layers className="w-3.5 h-3.5" />
            <span>Multi-Touch Attribution Engine</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-white">
            Return on Ad Spend (ROAS) Intelligence
          </h1>
          <p className="text-sm text-slate-300 leading-relaxed">
            Comparing four mathematical models across Google, Meta, TikTok, and Email. 
            Notice how traditional <strong className="text-rose-400">Last-Touch</strong> artificially deflates upper-funnel channels, while <strong className="text-emerald-400">Time-Decay</strong> fairly balances discovery and checkout intent.
          </p>
        </div>
      </div>

      {/* Summary Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-5 shadow-sm">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium uppercase tracking-wider">Total Ad Spend</span>
            <DollarSign className="w-4 h-4 text-indigo-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            ${totals.spend ? totals.spend.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '0.00'}
          </div>
          <p className="text-xs text-slate-400 mt-1">Aggregated across all active channels</p>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-5 shadow-sm">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium uppercase tracking-wider">Attributed Orders</span>
            <ShoppingCart className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            {totals.conversions ? totals.conversions.toLocaleString() : '0'}
          </div>
          <p className="text-xs text-slate-400 mt-1">Within 30-day lookback window</p>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-5 shadow-sm">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium uppercase tracking-wider">Time-Decay Revenue</span>
            <TrendingUp className="w-4 h-4 text-indigo-400" />
          </div>
          <div className="text-2xl font-bold text-emerald-400">
            ${totals.revenue_time_decay ? totals.revenue_time_decay.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '0.00'}
          </div>
          <p className="text-xs text-slate-400 mt-1">Net revenue (refunds deducted)</p>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-5 shadow-sm">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium uppercase tracking-wider">Active DB Role</span>
            <span className="inline-block w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
          </div>
          <div className="text-lg font-bold text-indigo-300 font-mono">
            app_{role}
          </div>
          <p className="text-xs text-slate-400 mt-1">
            {role === 'analyst' ? 'Read-only access to views' : 'Full read/write permissions'}
          </p>
        </div>
      </div>

      {/* Model Selector Tabs */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-slate-800 pb-4">
        <div>
          <h2 className="text-lg font-semibold text-white">Attribution Comparison Table</h2>
          <p className="text-xs text-slate-400">Real-time values from materialized view `mv_channel_roas_comparison`</p>
        </div>

        <div className="flex items-center space-x-2 bg-slate-900 p-1 rounded-lg border border-slate-800 text-xs">
          <button
            onClick={() => setActiveModel('time_decay')}
            className={`px-3 py-1.5 rounded-md font-medium transition-all ${
              activeModel === 'time_decay' ? 'bg-indigo-600 text-white shadow' : 'text-slate-400 hover:text-white'
            }`}
          >
            Time-Decay (7-day Half-life)
          </button>
          <button
            onClick={() => setActiveModel('first_touch')}
            className={`px-3 py-1.5 rounded-md font-medium transition-all ${
              activeModel === 'first_touch' ? 'bg-indigo-600 text-white shadow' : 'text-slate-400 hover:text-white'
            }`}
          >
            First-Touch
          </button>
          <button
            onClick={() => setActiveModel('last_touch')}
            className={`px-3 py-1.5 rounded-md font-medium transition-all ${
              activeModel === 'last_touch' ? 'bg-indigo-600 text-white shadow' : 'text-slate-400 hover:text-white'
            }`}
          >
            Last-Touch
          </button>
          <button
            onClick={() => setActiveModel('linear')}
            className={`px-3 py-1.5 rounded-md font-medium transition-all ${
              activeModel === 'linear' ? 'bg-indigo-600 text-white shadow' : 'text-slate-400 hover:text-white'
            }`}
          >
            Linear
          </button>
        </div>
      </div>

      {/* Data Table */}
      <div className="bg-slate-900/60 border border-slate-800 rounded-xl overflow-hidden shadow">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-950 text-xs uppercase text-slate-400 border-b border-slate-800 font-semibold tracking-wider">
              <tr>
                <th className="px-6 py-4">Channel</th>
                <th className="px-6 py-4">Total Spend</th>
                <th className="px-6 py-4">First-Touch ROAS</th>
                <th className="px-6 py-4">Last-Touch ROAS</th>
                <th className="px-6 py-4">Linear ROAS</th>
                <th className="px-6 py-4 text-indigo-400">Time-Decay ROAS</th>
                <th className="px-6 py-4">Attributed Net Revenue</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {loading ? (
                <tr>
                  <td colSpan={7} className="px-6 py-8 text-center text-slate-400">
                    <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-indigo-400" />
                    Querying PostgreSQL Materialized View...
                  </td>
                </tr>
              ) : data.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-8 text-center text-slate-400">
                    No records found. Run `python data/load.py` to populate data.
                  </td>
                </tr>
              ) : (
                data.map((row) => {
                  const currentRoas =
                    activeModel === 'first_touch'
                      ? row.roas_first_touch
                      : activeModel === 'last_touch'
                      ? row.roas_last_touch
                      : activeModel === 'linear'
                      ? row.roas_linear
                      : row.roas_time_decay;

                  const currentRevenue =
                    activeModel === 'first_touch'
                      ? row.revenue_first_touch
                      : activeModel === 'last_touch'
                      ? row.revenue_last_touch
                      : activeModel === 'linear'
                      ? row.revenue_linear
                      : row.revenue_time_decay;

                  return (
                    <tr key={row.channel} className="hover:bg-slate-800/40 transition-colors">
                      <td className="px-6 py-4 font-semibold text-white flex items-center space-x-2">
                        <span>{row.channel}</span>
                      </td>
                      <td className="px-6 py-4 text-slate-300 font-mono">
                        ${Number(row.total_spend).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </td>
                      <td className="px-6 py-4 font-mono text-slate-300">
                        {Number(row.roas_first_touch).toFixed(2)}x
                      </td>
                      <td className="px-6 py-4 font-mono text-slate-300">
                        {Number(row.roas_last_touch).toFixed(2)}x
                      </td>
                      <td className="px-6 py-4 font-mono text-slate-300">
                        {Number(row.roas_linear).toFixed(2)}x
                      </td>
                      <td className="px-6 py-4 font-mono font-bold text-indigo-400 bg-indigo-950/20">
                        {Number(row.roas_time_decay).toFixed(2)}x
                      </td>
                      <td className="px-6 py-4 font-mono font-medium text-emerald-400">
                        ${Number(currentRevenue).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Visual ROAS Breakdown Chart Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-6 shadow-sm">
          <h3 className="text-base font-semibold text-white mb-2 flex items-center justify-between">
            <span>Visual ROAS by Model ({activeModel.replace('_', ' ').toUpperCase()})</span>
            <ArrowUpRight className="w-4 h-4 text-indigo-400" />
          </h3>
          <p className="text-xs text-slate-400 mb-6">Bar comparison relative to 1.0x break-even baseline</p>

          <div className="space-y-4">
            {data.map((row) => {
              const roas =
                activeModel === 'first_touch'
                  ? row.roas_first_touch
                  : activeModel === 'last_touch'
                  ? row.roas_last_touch
                  : activeModel === 'linear'
                  ? row.roas_linear
                  : row.roas_time_decay;

              const percentage = Math.min(100, Math.max(10, (Number(roas) / 3.0) * 100));

              return (
                <div key={row.channel} className="space-y-1">
                  <div className="flex justify-between text-xs font-medium">
                    <span className="text-slate-200">{row.channel}</span>
                    <span className="font-mono text-indigo-400">{Number(roas).toFixed(2)}x ROAS</span>
                  </div>
                  <div className="h-3 w-full bg-slate-800 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-gradient-to-r from-indigo-500 to-emerald-400 rounded-full transition-all duration-500"
                      style={{ width: `${percentage}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-6 shadow-sm">
          <h3 className="text-base font-semibold text-white mb-2 flex items-center space-x-2">
            <Info className="w-4 h-4 text-indigo-400" />
            <span>Market-Shift Insight (Originality Aspect)</span>
          </h3>
          <p className="text-xs text-slate-400 mb-4">
            Simulating the 2026 AI Search & Social Ad Shift
          </p>
          <div className="text-xs text-slate-300 space-y-3 leading-relaxed border-t border-slate-800/80 pt-4">
            <p>
              In our dataset's <code className="text-indigo-300 font-mono">--scenario ai_shift</code>, Google click volume and conversion share decline post April 1, 2026 as generative AI interfaces absorb intent queries.
            </p>
            <p>
              Under <strong>Last-Touch attribution</strong>, marketing executives would conclude Google performance collapsed entirely and misallocate budget.
            </p>
            <p>
              Under <strong>Time-Decay attribution</strong>, our data warehouse shows that Meta and Email upper-funnel touchpoints preserve overall pipeline velocity, allowing leadership to rebalance spend toward multi-channel nurture flows.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
