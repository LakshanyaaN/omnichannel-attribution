'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { 
  BarChart3, 
  GitFork, 
  Sparkles, 
  Database, 
  ShieldCheck, 
  UserCheck 
} from 'lucide-react';

interface RoleContextType {
  role: 'analyst' | 'manager';
  setRole: (r: 'analyst' | 'manager') => void;
}

const RoleContext = createContext<RoleContextType>({
  role: 'analyst',
  setRole: () => {},
});

export const useRole = () => useContext(RoleContext);

export function RoleProvider({ children }: { children: React.ReactNode }) {
  const [role, setRoleState] = useState<'analyst' | 'manager'>('analyst');

  useEffect(() => {
    const saved = localStorage.getItem('app_user_role') as 'analyst' | 'manager';
    if (saved) setRoleState(saved);
  }, []);

  const setRole = (newRole: 'analyst' | 'manager') => {
    setRoleState(newRole);
    localStorage.setItem('app_user_role', newRole);
  };

  return (
    <RoleContext.Provider value={{ role, setRole }}>
      {children}
    </RoleContext.Provider>
  );
}

export default function Navigation() {
  const pathname = usePathname();
  const { role, setRole } = useRole();

  const navItems = [
    { label: 'Attribution & ROAS', href: '/', icon: BarChart3 },
    { label: 'Journey Paths', href: '/journeys', icon: GitFork },
    { label: 'Vector Search', href: '/creatives', icon: Sparkles },
    { label: 'MongoDB Events (RUD)', href: '/raw-events', icon: Database },
    { label: 'Campaigns & RBAC', href: '/campaigns', icon: ShieldCheck },
  ];

  return (
    <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
        {/* Brand */}
        <div className="flex items-center space-x-3">
          <div className="h-9 w-9 rounded-lg bg-indigo-600 flex items-center justify-center font-bold text-white shadow-lg shadow-indigo-500/25">
            MTA
          </div>
          <div>
            <div className="font-semibold text-white tracking-tight leading-none">
              AttributionEngine
            </div>
            <div className="text-[10px] text-slate-400 font-mono mt-0.5">
              PESU DBMS LEVEL 3
            </div>
          </div>
        </div>

        {/* Navigation Links */}
        <nav className="hidden md:flex items-center space-x-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center space-x-2 px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-slate-800 text-indigo-400 shadow-sm'
                    : 'text-slate-300 hover:text-white hover:bg-slate-800/50'
                }`}
              >
                <Icon className="w-4 h-4" />
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* Database-Enforced Role Switcher */}
        <div className="flex items-center space-x-3">
          <div className="flex items-center space-x-2 bg-slate-950 px-3 py-1.5 rounded-full border border-slate-800 text-xs">
            <UserCheck className="w-3.5 h-3.5 text-indigo-400" />
            <span className="text-slate-400 font-medium">DB Role:</span>
            <select
              value={role}
              onChange={(e) => setRole(e.target.value as 'analyst' | 'manager')}
              className="bg-transparent font-semibold text-indigo-300 focus:outline-none cursor-pointer"
            >
              <option value="analyst" className="bg-slate-900 text-slate-200">
                Analyst (app_analyst - Read Only)
              </option>
              <option value="manager" className="bg-slate-900 text-slate-200">
                Manager (app_manager - Read/Write)
              </option>
            </select>
          </div>
        </div>
      </div>
    </header>
  );
}
