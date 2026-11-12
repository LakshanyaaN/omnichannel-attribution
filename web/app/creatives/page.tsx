'use client';

import React, { useState, useEffect } from 'react';
import { useRole } from '@/components/Navigation';
import { Sparkles, Search, Tag, RefreshCw } from 'lucide-react';

interface Creative {
  creative_id: string;
  headline: string;
  body_text: string;
  call_to_action: string;
  campaign_name: string;
  channel: string;
  similarity_score: number;
}

export default function CreativesPage() {
  const { role } = useRole();
  const [searchTerm, setSearchTerm] = useState('Attribution');
  const [channelFilter, setChannelFilter] = useState('ALL');
  const [creatives, setCreatives] = useState<Creative[]>([]);
  const [loading, setLoading] = useState(false);

  const searchCreatives = async () => {
    setLoading(true);
    try {
      const res = await fetch(
        `/api/creatives/search?q=${encodeURIComponent(searchTerm)}&channel=${channelFilter}&role=${role}`
      );
      const json = await res.json();
      if (json.success) {
        setCreatives(json.data);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    searchCreatives();
  }, [channelFilter, role]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') searchCreatives();
  };

  return (
    <div className="space-y-6">
      <div className="border-b border-slate-800 pb-5">
        <div className="inline-flex items-center space-x-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 mb-2">
          <Sparkles className="w-3.5 h-3.5" />
          <span>PostgreSQL pgvector Dense Embeddings</span>
        </div>
        <h1 className="text-2xl font-bold text-white tracking-tight">
          Semantic Ad Creative Intelligence
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Perform high-dimensional cosine similarity search (<code className="text-indigo-300 font-mono">&lt;=&gt;</code>) over 384-dimensional creative vectors
        </p>
      </div>

      {/* Search Bar & Channel Filter */}
      <div className="flex flex-col sm:flex-row items-center gap-3">
        <div className="relative flex-1 w-full">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Search ad headlines (e.g. 'Attribution', 'Budget', 'ROAS', 'Checkout')..."
            className="w-full bg-slate-900 border border-slate-800 rounded-xl pl-10 pr-4 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 transition"
          />
        </div>

        <select
          value={channelFilter}
          onChange={(e) => setChannelFilter(e.target.value)}
          className="bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5 text-sm text-slate-300 focus:outline-none focus:border-indigo-500 w-full sm:w-auto cursor-pointer"
        >
          <option value="ALL">All Platforms</option>
          <option value="Google">Google</option>
          <option value="Meta">Meta</option>
          <option value="TikTok">TikTok</option>
          <option value="Email">Email</option>
        </select>

        <button
          onClick={searchCreatives}
          className="w-full sm:w-auto px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold shadow-md shadow-indigo-600/25 transition"
        >
          Search Vectors
        </button>
      </div>

      {/* Results Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {loading ? (
          <div className="col-span-full bg-slate-900/60 border border-slate-800 rounded-xl p-12 text-center text-slate-400">
            <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-3 text-indigo-400" />
            Computing Cosine Distance in pgvector...
          </div>
        ) : creatives.length === 0 ? (
          <div className="col-span-full bg-slate-900/60 border border-slate-800 rounded-xl p-12 text-center text-slate-400">
            No matching creatives found.
          </div>
        ) : (
          creatives.map((c) => (
            <div
              key={c.creative_id}
              className="bg-slate-900/60 border border-slate-800 rounded-xl p-5 hover:border-indigo-500/40 transition-all flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-[11px] font-semibold tracking-wider uppercase px-2 py-0.5 rounded bg-slate-800 text-slate-300 border border-slate-700">
                    {c.channel}
                  </span>
                  <div className="flex items-center space-x-1.5 text-xs font-mono text-emerald-400 bg-emerald-950/40 border border-emerald-800/40 px-2 py-0.5 rounded-full">
                    <span>Similarity:</span>
                    <strong>{Number(c.similarity_score * 100).toFixed(1)}%</strong>
                  </div>
                </div>

                <h3 className="text-base font-semibold text-white mb-1.5 leading-snug">
                  {c.headline}
                </h3>
                <p className="text-xs text-slate-400 leading-relaxed mb-4">
                  {c.body_text}
                </p>
              </div>

              <div className="border-t border-slate-800/80 pt-3 flex items-center justify-between text-xs text-slate-400">
                <span className="truncate max-w-[200px] text-slate-400">{c.campaign_name}</span>
                <span className="inline-flex items-center space-x-1 text-indigo-400 font-medium">
                  <Tag className="w-3 h-3" />
                  <span>{c.call_to_action}</span>
                </span>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
