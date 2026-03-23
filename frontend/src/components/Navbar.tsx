import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useWeb3 } from '../context/Web3Context';

export default function Navbar() {
  const { account, roles, isConnected, openModal } = useWeb3();
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);

  const navLinks: { to: string; label: string }[] = [
    { to: '/', label: 'Home' },
    { to: '/elections', label: 'Elections' },
    { to: '/parties', label: 'Parties' },
  ];

  if (isConnected && roles.isRegisteredVoter) {
    navLinks.push({ to: '/dashboard', label: 'Dashboard' });
  }
  if (isConnected && (roles.isPartyMember || roles.isPartyLeader)) {
    navLinks.push({ to: '/party', label: 'My Party' });
  }
  if (isConnected && roles.isAdmin) {
    navLinks.push({ to: '/admin', label: 'Admin' });
  }

  return (
    <nav className="sticky top-0 z-50 bg-white/80 backdrop-blur-xl border-b border-gray-100">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link to="/" className="flex items-center gap-2.5 group">
            <div className="w-9 h-9 rounded-lg brand-gradient flex items-center justify-center shadow-md">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
                <polyline points="9 22 9 12 15 12 15 22" />
              </svg>
            </div>
            <div>
              <span className="text-lg font-bold text-gray-900 tracking-tight">FedVote</span>
              <span className="hidden sm:block text-[10px] font-medium text-brand-500 tracking-widest uppercase -mt-1">Web3 Governance</span>
            </div>
          </Link>

          {/* Desktop Nav */}
          <div className="hidden md:flex items-center gap-1">
            {navLinks.map(({ to, label }) => (
              <Link
                key={to}
                to={to}
                className={`px-3.5 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                  location.pathname === to
                    ? 'text-brand-600 bg-brand-50'
                    : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
                }`}
              >
                {label}
              </Link>
            ))}
          </div>

          {/* Right side - AppKit Button + badges */}
          <div className="flex items-center gap-3">
            {isConnected && roles.hasDemocracyBadge && (
              <span className="badge badge-success hidden sm:inline-flex">🏅 Badge</span>
            )}

            {/* Reown AppKit web component — handles connect/disconnect/account */}

            {isConnected && account ? (
              <button
                onClick={openModal}
                className="group flex items-center gap-2.5 px-4 py-2.5 rounded-xl bg-brand-50 border border-brand-100 text-brand-600 text-sm font-semibold transition-all duration-250 hover:bg-brand-100 hover:border-brand-200 hover:scale-[1.03] hover:shadow-md hover:shadow-brand-500/10 active:scale-100"
              >
                <span className="w-2 h-2 rounded-full bg-brand-500 animate-pulse" />
                {account.slice(0, 6)}...{account.slice(-4)}
              </button>
            ) : (
              <button
                onClick={openModal}
                className="flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold text-white brand-gradient shadow-md shadow-brand-500/30 transition-all duration-250 hover:shadow-lg hover:shadow-brand-500/40 hover:-translate-y-0.5 hover:scale-[1.03] active:translate-y-0 active:scale-100"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="2" y="6" width="20" height="12" rx="2" /><path d="M22 10H18a2 2 0 000 4h4" /></svg>
                Connect Wallet
              </button>
            )}




            {/* Mobile menu toggle */}
            <button
              className="md:hidden p-2 rounded-lg hover:bg-gray-100"
              onClick={() => setMenuOpen(!menuOpen)}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                {menuOpen
                  ? <path d="M18 6L6 18M6 6l12 12" />
                  : <path d="M3 12h18M3 6h18M3 18h18" />
                }
              </svg>
            </button>
          </div>
        </div>

        {/* Mobile Menu */}
        {menuOpen && (
          <div className="md:hidden py-3 border-t border-gray-100 animate-slide-down">
            {navLinks.map(({ to, label }) => (
              <Link
                key={to}
                to={to}
                onClick={() => setMenuOpen(false)}
                className={`block px-4 py-2.5 rounded-lg text-sm font-medium ${
                  location.pathname === to ? 'text-brand-600 bg-brand-50' : 'text-gray-600'
                }`}
              >
                {label}
              </Link>
            ))}
          </div>
        )}
      </div>
    </nav>
  );
}
