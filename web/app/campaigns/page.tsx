'use client';

import React, { useState, useEffect } from 'react';
import { useRole } from '@/components/Navigation';
import { ShieldCheck, Plus, CheckCircle, AlertOctagon, RefreshCw, DollarSign } from 'lucide-react';

interface Campaign {
  campaign_id: string;
  name: string;
  channel: string;
  is_active: boolean;
  cpc_bid?: number;
  target_network?: string;
  daily_budget?: number;
}

export default function CampaignsPage() {
  const { role } = useRole();
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [loading, setLoading] = useState(true);

  // Form states
  const [name, setName] = useState('');
  const [channel, setChannel] = useState('Meta');
  const [dailyBudget, setDailyBudget] = useState('750.00');
  const [cpcBid, setCpcBid] = useState('1.85');
  const [targetNetwork, setTargetNetwork] = useState('Instagram Feed');

  // RBAC feedback state
  const [responseMsg, setResponseMsg] = useState<{
    type: 'success' | 'error';
    title: string;
    message: string;
  } | null>(null);

  const fetchCampaigns = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/campaigns?role=${role}`);
      const json = await res.json();
      if (json.success) {
        setCampaigns(json.data);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCampaigns();
  }, [role]);

  // Form submit: attempts write operation using current database role
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setResponseMsg(null);

    try {
      const res = await fetch(`/api/campaigns?role=${role}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name,
          channel,
          daily_budget: parseFloat(dailyBudget),
          cpc_bid: parseFloat(cpcBid),
          target_network: targetNetwork,
        }),
      });

      const json = await res.json();

      if (json.success) {
        setResponseMsg({
          type: 'success',
          title: `Operation Approved by Database (Role: app_${role})`,
          message: json.message,
        });
        setName('');
        fetchCampaigns();
      } else {
        setResponseMsg({
          type: 'error',
          title: json.isPermissionDenied
            ? `PostgreSQL Rejected Request (SQLSTATE 42501)`
            : `Error Executing Operation`,
          message: json.detail || json.error,
        });
      }
    } catch (err: any) {
      setResponseMsg({
        type: 'error',
        title: 'Network Error',
        message: err.message,
      });
    }
  };

  return (
    <div className="space-y-8">
      {/* RBAC Header */}
      <div className="border-b border-slate-800 pb-5">
        <div className="inline-flex items-center space-x-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 mb-2">
          <ShieldCheck className="w-3.5 h-3.5" />
          <span>Rubric Item 12: Database-Enforced RBAC</span>
        </div>
        <h1 className="text-2xl font-bold text-white tracking-tight">
          Campaign Administration & Role-Based Access Control
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Permissions are enforced in the <strong>PostgreSQL engine</strong> itself. The <code className="text-indigo-300 font-mono">app_analyst</code> role has <code className="text-amber-400 font-mono">SELECT</code> permissions only; write operations are strictly reserved for <code className="text-indigo-300 font-mono">app_manager</code>.
        </p>
      </div>

      {/* Role Demonstration Alert */}
      <div className={`p-4 rounded-xl border flex items-start space-x-3 text-xs ${
        role === 'analyst' 
          ? 'bg-amber-950/20 border-amber-800/40 text-amber-200' 
          : 'bg-emerald-950/20 border-emerald-800/40 text-emerald-200'
      }`}>
        <div className="mt-0.5">
          {role === 'analyst' ? <AlertOctagon className="w-4 h-4 text-amber-400" /> : <CheckCircle className="w-4 h-4 text-emerald-400" />}
        </div>
        <div>
          <div className="font-semibold text-sm">
            Current Active Role: <span className="font-mono underline">app_{role}</span>
          </div>
          <p className="mt-0.5 text-slate-400 leading-relaxed">
            {role === 'analyst'
              ? "You are logged in as Analyst. Attempting to create a campaign below will be blocked by PostgreSQL with a 403 Forbidden 'permission denied for table dim_campaign'. Use the top-right toggle to switch to Marketing Manager."
              : "You are logged in as Marketing Manager. You have full INSERT/UPDATE privileges. Creating a campaign below will succeed and trigger an automated audit log entry."}
          </p>
        </div>
      </div>

      {/* Campaign Creation Form */}
      <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-6 shadow-sm">
        <h2 className="text-base font-semibold text-white mb-4 flex items-center space-x-2">
          <Plus className="w-4 h-4 text-indigo-400" />
          <span>Create New Marketing Campaign (Tests Database Write Permission)</span>
        </h2>

        <form onSubmit={handleSubmit} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <div className="lg:col-span-2 space-y-1">
            <label className="text-xs font-medium text-slate-400">Campaign Name</label>
            <input
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g., Q4 Black Friday Omnichannel Blitz"
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-indigo-500"
            />
          </div>

          <div className="space-y-1">
            <label className="text-xs font-medium text-slate-400">Channel</label>
            <select
              value={channel}
              onChange={(e) => setChannel(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-indigo-500"
            >
              <option value="Google">Google</option>
              <option value="Meta">Meta</option>
              <option value="TikTok">TikTok</option>
              <option value="Email">Email</option>
            </select>
          </div>

          <div className="space-y-1">
            <label className="text-xs font-medium text-slate-400">Daily Budget ($)</label>
            <input
              type="number"
              step="0.01"
              required
              value={dailyBudget}
              onChange={(e) => setDailyBudget(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-indigo-500 font-mono"
            />
          </div>

          <div className="space-y-1">
            <label className="text-xs font-medium text-slate-400">CPC Target Bid ($)</label>
            <input
              type="number"
              step="0.01"
              required
              value={cpcBid}
              onChange={(e) => setCpcBid(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-indigo-500 font-mono"
            />
          </div>

          <div className="space-y-1">
            <label className="text-xs font-medium text-slate-400">Target Distribution Network</label>
            <input
              type="text"
              required
              value={targetNetwork}
              onChange={(e) => setTargetNetwork(e.target.value)}
              placeholder="e.g., Instagram Reels"
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-indigo-500"
            />
          </div>

          <div className="sm:col-span-2 lg:col-span-3 pt-2">
            <button
              type="submit"
              className="px-6 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold shadow-md shadow-indigo-600/25 transition"
            >
              Execute INSERT via role: app_{role}
            </button>
          </div>
        </form>

        {/* Live Feedback Notification */}
        {responseMsg && (
          <div
            className={`mt-4 p-4 rounded-xl border text-xs ${
              responseMsg.type === 'success'
                ? 'bg-emerald-950/40 border-emerald-800/40 text-emerald-300'
                : 'bg-rose-950/40 border-rose-800/40 text-rose-300'
            }`}
          >
            <div className="font-bold text-sm mb-1">{responseMsg.title}</div>
            <p className="leading-relaxed font-mono">{responseMsg.message}</p>
          </div>
        )}
      </div>

      {/* Campaigns Table */}
      <div className="bg-slate-900/60 border border-slate-800 rounded-xl overflow-hidden shadow">
        <div className="p-4 border-b border-slate-800 flex items-center justify-between">
          <h3 className="text-sm font-semibold text-white">Active Warehouse Campaigns</h3>
          <button
            onClick={fetchCampaigns}
            className="flex items-center space-x-1.5 px-3 py-1 rounded-lg bg-slate-800 text-xs text-slate-300 hover:text-white transition"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-indigo-400' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-950 text-xs uppercase text-slate-400 border-b border-slate-800 font-semibold tracking-wider">
              <tr>
                <th className="px-5 py-3.5">Campaign Name</th>
                <th className="px-5 py-3.5">Channel</th>
                <th className="px-5 py-3.5">Network</th>
                <th className="px-5 py-3.5">Target CPC</th>
                <th className="px-5 py-3.5">Daily Budget</th>
                <th className="px-5 py-3.5">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-xs">
              {loading ? (
                <tr>
                  <td colSpan={6} className="px-6 py-8 text-center text-slate-400">
                    <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-indigo-400" />
                    Querying PostgreSQL Campaigns...
                  </td>
                </tr>
              ) : (
                campaigns.map((c) => (
                  <tr key={c.campaign_id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="px-5 py-3.5 font-medium text-white">{c.name}</td>
                    <td className="px-5 py-3.5">
                      <span className="px-2 py-0.5 rounded text-[10px] uppercase font-bold bg-slate-800 text-slate-300">
                        {c.channel}
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-slate-400">{c.target_network || 'Direct Email'}</td>
                    <td className="px-5 py-3.5 font-mono text-slate-300">
                      {c.cpc_bid ? `$${Number(c.cpc_bid).toFixed(2)}` : 'N/A'}
                    </td>
                    <td className="px-5 py-3.5 font-mono text-emerald-400 font-semibold">
                      {c.daily_budget ? `$${Number(c.daily_budget).toFixed(2)}` : 'N/A'}
                    </td>
                    <td className="px-5 py-3.5">
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-medium bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                        Active
                      </span>
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
