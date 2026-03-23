import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useWeb3 } from '../context/Web3Context';
import { ethers } from 'ethers';
import { ADDRESSES, CHAIN_CONFIG, RegistryABI, ElectionABI } from '../config/contracts';

export default function Landing() {
  const { account, openModal, roles, loading, isConnected } = useWeb3();
  const [stats, setStats] = useState({ voters: '—', elections: '—' });

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const rpc = new ethers.JsonRpcProvider(CHAIN_CONFIG.rpcUrl);
        const reg = new ethers.Contract(ADDRESSES.Registry, RegistryABI, rpc);
        const el = new ethers.Contract(ADDRESSES.Election, ElectionABI, rpc);
        const [totalVoters, currentElection] = await Promise.all([
          reg.totalRegisteredVoters(), el.currentElectionId(),
        ]);
        setStats({ voters: Number(totalVoters).toLocaleString(), elections: Number(currentElection).toString() });
      } catch (e) { console.log('Stats fetch error:', e); }
    };
    fetchStats();
  }, []);

  return (
    <div className="relative overflow-hidden">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-[600px] h-[600px] rounded-full bg-brand-500/5 blur-3xl" />
        <div className="absolute top-60 -left-40 w-[400px] h-[400px] rounded-full bg-brand-400/5 blur-3xl" />
      </div>

      <section className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-16 pb-20 lg:pt-24 lg:pb-28">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          <div>
            <div className="animate-fade-up">
              <span className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-brand-50 text-brand-600 text-xs font-semibold tracking-wide uppercase mb-6">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                Decentralized Civic Protocol
              </span>
            </div>
            <h1 className="text-4xl sm:text-5xl lg:text-[3.5rem] font-bold text-gray-900 leading-[1.1] tracking-tight animate-fade-up stagger-1">
              Trusted elections,{' '}<span className="text-gradient">verified on-chain</span>,{' '}open to every eligible citizen.
            </h1>
            <p className="mt-6 text-lg text-gray-500 leading-relaxed max-w-lg animate-fade-up stagger-2">
              FedVote turns voting into a transparent public good: wallet-based identity, immutable ballot trails, and governance participation rewards in one secure experience.
            </p>
            <div className="mt-8 flex flex-wrap items-center gap-4 animate-fade-up stagger-3">
              {!isConnected ? (
                <button onClick={openModal} disabled={loading} className="btn-primary text-base !py-3.5 !px-8">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="2" y="6" width="20" height="12" rx="2" /><path d="M22 10H18a2 2 0 000 4h4" /></svg>
                  Connect Wallet
                </button>
              ) : roles.isRegisteredVoter ? (
                <Link to="/dashboard" className="btn-primary text-base !py-3.5 !px-8">Go to Dashboard →</Link>
              ) : roles.isAuthorizedCitizen ? (
                <Link to="/register" className="btn-primary text-base !py-3.5 !px-8">Register as Voter →</Link>
              ) : (
                <Link to="/elections" className="btn-primary text-base !py-3.5 !px-8">View Elections →</Link>
              )}
              <Link to="/parties" className="btn-secondary text-base">View Parties</Link>
              <a href="#how-it-works" className="btn-ghost text-base text-gray-500">Learn More →</a>
            </div>
          </div>

          <div className="animate-fade-up stagger-3">
            <div className="relative">
              <div className="absolute inset-0 brand-gradient rounded-2xl blur-xl opacity-20 scale-105" />
              <div className="relative brand-gradient rounded-2xl p-8 text-white overflow-hidden">
                <div className="absolute top-0 right-0 w-40 h-40 bg-white/5 rounded-full -translate-y-1/2 translate-x-1/2" />
                <div className="absolute bottom-0 left-0 w-32 h-32 bg-white/5 rounded-full translate-y-1/2 -translate-x-1/2" />
                <p className="text-xs font-semibold tracking-widest uppercase text-white/70 mb-2">Governance Snapshot</p>
                <h3 className="text-xl font-bold mb-6">Federal General Election</h3>
                <div className="grid grid-cols-2 gap-4 mb-6">
                  <div className="bg-white/10 backdrop-blur rounded-xl p-4"><p className="text-xs text-white/60 mb-1">Registered Voters</p><p className="text-2xl font-bold">{stats.voters}</p></div>
                  <div className="bg-white/10 backdrop-blur rounded-xl p-4"><p className="text-xs text-white/60 mb-1">Election Cycles</p><p className="text-2xl font-bold">{stats.elections}</p></div>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="flex items-center gap-3 bg-white/10 backdrop-blur rounded-xl p-4">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0110 0v4" /></svg>
                    <span className="text-xs font-medium text-white/80">Zero-knowledge ballot privacy</span>
                  </div>
                  <div className="flex items-center gap-3 bg-white/10 backdrop-blur rounded-xl p-4">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                    <span className="text-xs font-medium text-white/80">Verifiable contract execution</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="how-it-works" className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <div className="text-center mb-14">
          <span className="badge badge-brand mb-4">How It Works</span>
          <h2 className="text-3xl sm:text-4xl font-bold text-gray-900 tracking-tight">Democracy in four steps</h2>
        </div>
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {[
            { step: '01', title: 'Get Authorized', desc: 'Submit your NIN and wallet to a Registration Office for on-chain authorization.', icon: 'M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z' },
            { step: '02', title: 'Self-Register', desc: 'Register on-chain with your NIN and name. Your identity is hashed for privacy.', icon: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z' },
            { step: '03', title: 'Accredit & Vote', desc: 'Accredit yourself for the current election and cast your vote — from anywhere.', icon: 'M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z' },
            { step: '04', title: 'Earn Rewards', desc: 'Keep voting consistently to earn a Democracy Badge NFT and NAT token rewards.', icon: 'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z' },
          ].map((item, i) => (
            <div key={i} className={`glass-card card-hover p-6 animate-fade-up stagger-${i + 1}`}>
              <div className="w-12 h-12 rounded-xl bg-brand-50 flex items-center justify-center mb-4">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#6C63FF" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={item.icon} /></svg>
              </div>
              <span className="text-xs font-bold text-brand-500 tracking-widest">{item.step}</span>
              <h3 className="text-lg font-bold text-gray-900 mt-1 mb-2">{item.title}</h3>
              <p className="text-sm text-gray-500 leading-relaxed">{item.desc}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <div className="grid lg:grid-cols-3 gap-6">
          <div className="glass-card p-8 lg:col-span-2">
            <span className="badge badge-brand mb-4">Incentive System</span>
            <h3 className="text-2xl font-bold text-gray-900 mb-3">Vote consistently, earn rewards</h3>
            <p className="text-gray-500 mb-6">Every 3 consecutive elections you vote in, you level up. Starting at 100 NAT, rewards grow at 1.3× per threshold.</p>
            <div className="grid grid-cols-5 gap-3">
              {[{ s: 3, r: '100' },{ s: 6, r: '130' },{ s: 9, r: '169' },{ s: 12, r: '220' },{ s: 15, r: '286' }].map((item) => (
                <div key={item.s} className="text-center p-3 rounded-xl bg-brand-50/50">
                  <p className="text-xs text-brand-500 font-semibold">Streak {item.s}</p>
                  <p className="text-lg font-bold text-gray-900">{item.r}</p>
                  <p className="text-[10px] text-gray-400">NAT</p>
                </div>
              ))}
            </div>
          </div>
          <div className="glass-card p-8 brand-gradient text-white">
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/15 text-xs font-semibold mb-4">🏅 Democracy Badge</span>
            <h3 className="text-2xl font-bold mb-3">Soulbound NFT</h3>
            <p className="text-white/80 text-sm leading-relaxed">At a 3-election voting streak, you receive a non-transferable Democracy Badge — permanent proof of your civic commitment, stored forever on-chain.</p>
          </div>
        </div>
      </section>

      <footer className="border-t border-gray-100 bg-white/50 py-10 mt-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-md brand-gradient flex items-center justify-center">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" /><polyline points="9 22 9 12 15 12 15 22" /></svg>
            </div>
            <span className="font-bold text-gray-900">FedVote</span>
          </div>
          <p className="text-sm text-gray-400">Built on Hedera · Transparent governance for every nation</p>
        </div>
      </footer>
    </div>
  );
}